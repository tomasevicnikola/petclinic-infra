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
  mysql_port = 3306

  password_secret_id = "${var.secret_prefix}-password"
  config_secret_id   = "${var.secret_prefix}-config"
}

ephemeral "random_password" "app" {
  length           = 32
  special          = true
  override_special = "-_.~"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

ephemeral "random_password" "root" {
  length           = 32
  special          = true
  override_special = "-_.~"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "google_sql_database_instance" "this" {
  project = var.project_id
  name    = var.instance_name
  region  = var.region

  database_version         = var.database_version
  root_password_wo         = ephemeral.random_password.root.result
  root_password_wo_version = var.password_version

  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    availability_type = var.availability_type
    edition           = "ENTERPRISE"

    disk_size             = var.disk_size_gb
    disk_type             = "PD_SSD"
    disk_autoresize       = true
    disk_autoresize_limit = var.disk_autoresize_limit_gb

    deletion_protection_enabled = var.deletion_protection

    user_labels = {
      component  = "database"
      managed-by = "terraform"
    }

    ip_configuration {
      ipv4_enabled       = false
      private_network    = var.network_self_link
      allocated_ip_range = var.allocated_ip_range
      ssl_mode           = "ENCRYPTED_ONLY"

      enable_private_path_for_google_cloud_services = false
    }

    database_flags {
      name  = "local_infile"
      value = "off"
    }

    backup_configuration {
      enabled                        = true
      binary_log_enabled             = true
      start_time                     = var.backup_start_time
      transaction_log_retention_days = var.transaction_log_retention_days

      backup_retention_settings {
        retained_backups = var.retained_backups
        retention_unit   = "COUNT"
      }
    }

    maintenance_window {
      day          = var.maintenance_day
      hour         = var.maintenance_hour
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = false
    }
  }

  lifecycle {
    ignore_changes = [settings[0].disk_size]
  }
}

resource "google_sql_database" "this" {
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  name     = var.database_name

  charset   = "utf8mb4"
  collation = "utf8mb4_unicode_ci"
}

resource "google_sql_user" "app" {
  project             = var.project_id
  instance            = google_sql_database_instance.this.name
  name                = var.app_user_name
  host                = var.app_user_host
  password_wo         = ephemeral.random_password.app.result
  password_wo_version = var.password_version
}

resource "google_secret_manager_secret" "app_password" {
  project   = var.project_id
  secret_id = local.password_secret_id

  labels = {
    component = "database"
  }

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "app_password" {
  secret                 = google_secret_manager_secret.app_password.id
  secret_data_wo         = ephemeral.random_password.app.result
  secret_data_wo_version = var.password_version
  deletion_policy        = "DISABLE"

  depends_on = [google_sql_user.app]

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_secret_manager_secret" "app_config" {
  project   = var.project_id
  secret_id = local.config_secret_id

  labels = {
    component = "database"
  }

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "app_config" {
  secret = google_secret_manager_secret.app_config.id

  secret_data = jsonencode({
    host     = google_sql_database_instance.this.private_ip_address
    port     = local.mysql_port
    database = google_sql_database.this.name
    username = google_sql_user.app.name
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_secret_manager_secret_iam_member" "app_password_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.app_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.app_service_account_email}"
}

resource "google_secret_manager_secret_iam_member" "app_config_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.app_config.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.app_service_account_email}"
}
