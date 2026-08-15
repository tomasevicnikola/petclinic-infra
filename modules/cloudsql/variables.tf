variable "project_id" {
  description = "GCP project to create the instance and secrets in."
  type        = string
}

variable "region" {
  description = "Region for the instance and for the secret replica."
  type        = string
}

variable "instance_name" {
  description = "Name of the Cloud SQL instance. Set per environment, so no default."
  type        = string
}

variable "database_version" {
  description = "Cloud SQL MySQL version."
  type        = string
  default     = "MYSQL_8_0"

  validation {
    condition     = can(regex("^MYSQL_8_", var.database_version))
    error_message = "database_version must be a MySQL 8 version, for example MYSQL_8_0."
  }
}

variable "tier" {
  description = "Machine tier. db-g1-small is the smallest shared core that runs MySQL 8 without swapping; prod would take a dedicated core."
  type        = string
  default     = "db-g1-small"
}

variable "availability_type" {
  description = "ZONAL in dev. REGIONAL adds a synchronous standby in a second zone and doubles the price."
  type        = string
  default     = "ZONAL"

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "availability_type must be ZONAL or REGIONAL."
  }
}

variable "disk_size_gb" {
  description = "Data disk size in GB at creation. Ignored afterwards, because autoresize owns the disk from then on."
  type        = number
  default     = 10

  validation {
    condition     = var.disk_size_gb >= 10
    error_message = "disk_size_gb must be at least 10, the Cloud SQL minimum."
  }
}

variable "disk_autoresize_limit_gb" {
  description = "Ceiling for automatic disk growth. The disk never shrinks, so this is the cost stop."
  type        = number
  default     = 50

  validation {
    condition     = var.disk_autoresize_limit_gb >= 10
    error_message = "disk_autoresize_limit_gb must be at least 10."
  }
}

variable "network_self_link" {
  description = "Self link of the VPC to take the private IP from. Its Private Service Access range and peering must already exist."
  type        = string

  validation {
    condition     = can(regex("/global/networks/[^/]+$", var.network_self_link))
    error_message = "network_self_link must be a full VPC self link ending in /global/networks/<name>."
  }
}

variable "allocated_ip_range" {
  description = "Name of the Private Service Access range to take the private IP from. Null lets Cloud SQL pick any range peered on the VPC, which is only unambiguous while there is exactly one."
  type        = string
  default     = null
}

variable "database_name" {
  description = "Application database created on the instance."
  type        = string
  default     = "petclinic"
}

variable "app_user_name" {
  description = "MySQL user the application connects as. Cloud SQL gives API-created users everything except FILE and SUPER; narrowing that needs a GRANT run from inside the VPC."
  type        = string
  default     = "petclinic"
}

variable "password_version" {
  description = "Bump to rotate the application password. One apply regenerates it, updates the MySQL user and adds a secret version."
  type        = number
  default     = 1

  validation {
    condition     = var.password_version >= 1
    error_message = "password_version must be at least 1."
  }
}

variable "app_user_host" {
  description = "Host pattern the application user may connect from. The instance has no public IP, so % never leaves the VPC."
  type        = string
  default     = "%"
}

variable "backup_start_time" {
  description = "Start of the daily backup window, HH:MM UTC."
  type        = string
  default     = "02:00"

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.backup_start_time))
    error_message = "backup_start_time must be HH:MM in 24-hour UTC, for example 02:00."
  }
}

variable "retained_backups" {
  description = "Number of automatic backups kept."
  type        = number
  default     = 7

  validation {
    condition     = var.retained_backups >= 1 && var.retained_backups <= 365
    error_message = "retained_backups must be between 1 and 365."
  }
}

variable "transaction_log_retention_days" {
  description = "Days of binary log kept for point-in-time recovery. MySQL allows at most 7."
  type        = number
  default     = 7

  validation {
    condition     = var.transaction_log_retention_days >= 1 && var.transaction_log_retention_days <= 7
    error_message = "transaction_log_retention_days must be between 1 and 7 for MySQL."
  }
}

variable "maintenance_day" {
  description = "Day of the week for the maintenance window, 1 is Monday."
  type        = number
  default     = 7

  validation {
    condition     = var.maintenance_day >= 1 && var.maintenance_day <= 7
    error_message = "maintenance_day must be between 1 and 7."
  }
}

variable "maintenance_hour" {
  description = "Hour of the maintenance window, UTC."
  type        = number
  default     = 4

  validation {
    condition     = var.maintenance_hour >= 0 && var.maintenance_hour <= 23
    error_message = "maintenance_hour must be between 0 and 23."
  }
}

variable "deletion_protection" {
  description = "Blocks deletion in Terraform and in the API. A teardown sets this to false, applies, and only then destroys."
  type        = bool
  default     = true
}

variable "secret_prefix" {
  description = "Prefix for the two secrets, which become <prefix>-password and <prefix>-config."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,200}$", var.secret_prefix))
    error_message = "secret_prefix may contain only letters, digits, hyphens and underscores."
  }
}

variable "app_service_account_email" {
  description = "Service account of the application VMs. Gets secretAccessor on these two secrets and nothing else. Created in bootstrap, not here."
  type        = string

  validation {
    condition     = can(regex("^[^@]+@[^.]+\\.iam\\.gserviceaccount\\.com$", var.app_service_account_email))
    error_message = "app_service_account_email must be a service account address, not a user account."
  }
}
