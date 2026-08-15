terraform {
  # 1.11 is the floor for write-only arguments. The rest of the repo asks for
  # >= 1.5; this module needs the newer one to keep its passwords out of state.
  required_version = ">= 1.11"

  required_providers {
    google = {
      source = "hashicorp/google"
      # secret_data_wo arrived in 6.14.
      version = "~> 7.0"
    }
    random = {
      source = "hashicorp/random"
      # ephemeral random_password arrived in 3.7.
      version = "~> 3.7"
    }
  }
}

locals {
  grafana_secret_id = "${var.secret_prefix}-grafana-admin-password"
  vault_secret_id   = "${var.secret_prefix}-ansible-vault-password"
}

# No runner token secret here. Registration tokens live about an hour and are
# spent on the first use, so a stored one is expired long before anything reads
# it. The runner is registered by hand from a token read at that moment.

# Both passwords take the ephemeral path:
#
#   - ephemeral random_password is opened when the graph reaches it and closed
#     at the end of the run. It has no state entry, so the value exists only in
#     memory and is regenerated on every plan and every apply.
#   - secret_data_wo is a write-only argument. Terraform hands it to the
#     provider during apply and drops it; write-only arguments read back as
#     null in state and never appear in a plan file.
#   - because nothing is stored, Terraform cannot diff the value. That is what
#     secret_data_wo_version is for: it is an ordinary stored number, and the
#     provider writes a new secret version only when that number changes. So a
#     freshly generated password on every run is harmless — bumping the version
#     variable is the only thing that rotates it.

ephemeral "random_password" "grafana_admin" {
  length           = 32
  special          = true
  override_special = "-_.~"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "google_secret_manager_secret" "grafana_admin" {
  project   = var.project_id
  secret_id = local.grafana_secret_id

  labels = {
    component = "monitoring"
  }

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "grafana_admin" {
  secret                 = google_secret_manager_secret.grafana_admin.id
  secret_data_wo         = ephemeral.random_password.grafana_admin.result
  secret_data_wo_version = var.grafana_password_version

  lifecycle {
    create_before_destroy = true
  }
}

ephemeral "random_password" "ansible_vault" {
  length           = 48
  special          = true
  override_special = "-_.~"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "google_secret_manager_secret" "ansible_vault" {
  project   = var.project_id
  secret_id = local.vault_secret_id

  labels = {
    component = "ansible"
  }

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "ansible_vault" {
  secret                 = google_secret_manager_secret.ansible_vault.id
  secret_data_wo         = ephemeral.random_password.ansible_vault.result
  secret_data_wo_version = var.vault_password_version

  lifecycle {
    create_before_destroy = true
  }
}

# Ansible runs from the ops VM, so that is the only identity that reads the
# vault password. Per secret, never a project-level role. Grafana's password
# gets its binding when the monitoring stack that consumes it exists.
resource "google_secret_manager_secret_iam_member" "ansible_vault_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.ansible_vault.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.ops_service_account_email}"
}
