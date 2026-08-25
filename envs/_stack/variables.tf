variable "project_id" {
  description = "GCP project that owns this environment."
  type        = string
}

variable "region" {
  description = "Region for regional resources."
  type        = string
}

variable "zone" {
  description = "Zone for zonal resources."
  type        = string
}

variable "environment" {
  description = "Environment name. Drives every resource name, secret id and the app-env instance metadata."
  type        = string

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment must be dev, qa or prod."
  }
}

variable "subnet_cidr" {
  description = "Primary IPv4 range of this environment's subnet."
  type        = string

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "subnet_cidr must be a valid IPv4 CIDR block."
  }
}

variable "psa_cidr" {
  description = "Range reserved for Private Service Access peering."
  type        = string

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/(1[6-9]|2[0-4])$", var.psa_cidr)) && can(cidrhost(var.psa_cidr, 0))
    error_message = "psa_cidr must be a valid IPv4 CIDR with a prefix between /16 and /24."
  }
}

variable "app_port" {
  description = "Port the application listens on."
  type        = number
  default     = 8080
}

variable "create_ops_vm" {
  description = "Whether this environment creates the shared ops VM."
  type        = bool
  default     = true
}

variable "ops_machine_type" {
  description = "Machine type of the ops VM. Holds two runners plus the monitoring stack, so it is sized for both running at once."
  type        = string
  default     = "e2-medium"
}

variable "create_artifact_registry" {
  description = "Whether this environment creates the shared image repository."
  type        = bool
  default     = true
}

variable "db_name" {
  description = "Application database name."
  type        = string
  default     = "petclinic"
}

variable "db_app_user" {
  description = "MySQL user the application connects as."
  type        = string
  default     = "petclinic"
}

variable "db_password_version" {
  description = "Bump to rotate the database password."
  type        = number
  default     = 1
}

variable "db_tier" {
  description = "Cloud SQL machine tier."
  type        = string
  default     = "db-g1-small"
}

variable "db_availability_type" {
  description = "ZONAL or REGIONAL."
  type        = string
  default     = "ZONAL"

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.db_availability_type)
    error_message = "db_availability_type must be ZONAL or REGIONAL."
  }
}

variable "db_deletion_protection" {
  description = "Deletion protection on the database, in Terraform and in the API."
  type        = bool
  default     = true
}

variable "db_retained_backups" {
  description = "Number of automatic backups kept."
  type        = number
  default     = 7
}

variable "db_transaction_log_retention_days" {
  description = "Days of binary log kept for point-in-time recovery. Maximum 7."
  type        = number
  default     = 7
}

variable "app_machine_type" {
  description = "Machine type of the application instances."
  type        = string
  default     = "e2-medium"
}

variable "app_image" {
  description = "Exact image self link to pin, or null to track the petclinic-app family."
  type        = string
  default     = null
}

variable "app_image_digest" {
  description = "Container digest to deploy. Empty reads deploy/<environment>/app-image-digest from the state bucket."
  type        = string
  default     = ""

  validation {
    condition     = var.app_image_digest == "" || can(regex("^sha256:[0-9a-f]{64}$", var.app_image_digest))
    error_message = "app_image_digest must be empty or a sha256 digest."
  }
}

variable "deploy_state_bucket" {
  description = "Bucket holding the deployed-digest pointer."
  type        = string
  default     = "petclinic-capstone-tfstate"
}

variable "app_min_replicas" {
  description = "Autoscaler floor."
  type        = number
  default     = 2
}

variable "app_max_replicas" {
  description = "Autoscaler ceiling."
  type        = number
  default     = 4
}

variable "app_cpu_target" {
  description = "Average CPU the autoscaler holds across the group."
  type        = number
  default     = 0.6
}

variable "app_enable_autohealing" {
  description = "Whether the group replaces instances failing the autohealing check."
  type        = bool
  default     = true
}

variable "lb_allowed_members" {
  description = "Identities IAP admits, as IAM members. No default: an unset value must stop the run."
  type        = list(string)
}

variable "iap_oauth_client_id" {
  description = "OAuth 2.0 client IAP authenticates against. Shared by every environment."
  type        = string
  default     = "923128095631-v96nc3sies5njkaghoublmacb74nmesr.apps.googleusercontent.com"
}

variable "iap_oauth_client_secret" {
  description = "Secret of iap_oauth_client_id, supplied as TF_VAR_iap_oauth_client_secret."
  type        = string
  sensitive   = true
}

variable "iap_oauth_client_secret_version" {
  description = "Bump after rotating the client secret in the console."
  type        = number
  default     = 1
}

variable "lb_domain" {
  description = "Domain for a managed certificate, or null for a self-signed one."
  type        = string
  default     = null
}

variable "vault_deletion_protection" {
  description = "Deletion protection on the Ansible Vault password secret."
  type        = bool
  default     = true
}

variable "vault_password_version" {
  description = "Bump to rotate the Ansible Vault password."
  type        = number
  default     = 1
}

variable "grafana_password_version" {
  description = "Bump to rotate the Grafana admin password."
  type        = number
  default     = 1
}

variable "create_cloud_monitoring" {
  description = "Whether to create the Cloud Monitoring dashboard and alert policies for this environment."
  type        = bool
  default     = true
}

variable "cloud_monitoring_cpu_threshold" {
  description = "CPU fraction that opens the Cloud Monitoring CPU alert. Kept equal to the Prometheus HighCPU threshold."
  type        = number
  default     = 0.8
}

variable "cloud_monitoring_notification_email" {
  description = "Address Cloud Monitoring alerts are emailed to. Null creates no channel; incidents stay in the console. Supplied as TF_VAR_cloud_monitoring_notification_email, never committed."
  type        = string
  default     = null
}

variable "registry_repository_id" {
  description = "Docker repository name."
  type        = string
  default     = "petclinic"
}

variable "registry_keep_recent_count" {
  description = "Most recent versions kept regardless of age."
  type        = number
  default     = 10
}

variable "registry_cleanup_dry_run" {
  description = "Run cleanup policies without deleting anything."
  type        = bool
  default     = false
}

variable "registry_untagged_retention_days" {
  description = "How long untagged images live."
  type        = number
  default     = 7
}

variable "registry_pr_retention_days" {
  description = "How long a pull-request image lives. Release tags are never deleted by age."
  type        = number
  default     = 14
}
