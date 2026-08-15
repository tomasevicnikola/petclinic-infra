terraform {
  required_version = ">= 1.11"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

locals {
  vault_secret_id = "${var.env_prefix}-ansible-vault-password"
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
  project             = var.project_id
  secret_id           = local.vault_secret_id
  deletion_protection = var.vault_deletion_protection

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
  deletion_policy        = "DISABLE"

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_secret_manager_secret_iam_member" "ansible_vault_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.ansible_vault.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.ops_service_account_email}"
}
