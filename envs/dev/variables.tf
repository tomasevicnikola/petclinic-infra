variable "project_id" {
  description = "GCP project that owns this environment."
  type        = string
  default     = "petclinic-capstone"
}

variable "region" {
  description = "Region for regional resources."
  type        = string
  default     = "europe-west3"
}

variable "zone" {
  description = "Zone for zonal resources."
  type        = string
  default     = "europe-west3-a"
}

variable "environment" {
  description = "Which environment this directory is."
  type        = string
}

variable "subnet_cidr" {
  description = "Primary IPv4 range of this environment's subnet."
  type        = string
}

variable "psa_cidr" {
  description = "Range reserved for Private Service Access peering."
  type        = string
}

variable "create_ops_vm" {
  description = "Whether this environment creates the shared ops VM."
  type        = bool
}

variable "create_artifact_registry" {
  description = "Whether this environment creates the shared image repository."
  type        = bool
}

variable "db_tier" {
  description = "Cloud SQL machine tier."
  type        = string
}

variable "db_availability_type" {
  description = "ZONAL or REGIONAL."
  type        = string
}

variable "db_deletion_protection" {
  description = "Deletion protection on the database."
  type        = bool
}

variable "db_retained_backups" {
  description = "Number of automatic backups kept."
  type        = number
}

variable "db_transaction_log_retention_days" {
  description = "Days of binary log kept for point-in-time recovery."
  type        = number
}

variable "db_password_version" {
  description = "Bump to rotate the database password."
  type        = number
  default     = 1
}

variable "app_machine_type" {
  description = "Machine type of the application instances."
  type        = string
}

variable "app_min_replicas" {
  description = "Autoscaler floor."
  type        = number
}

variable "app_max_replicas" {
  description = "Autoscaler ceiling."
  type        = number
}

variable "app_image" {
  description = "Exact image self link to pin, or null to track the petclinic-app family."
  type        = string
  default     = null
}

variable "app_image_digest" {
  description = "Container digest to deploy. Empty reads deploy/<environment>/app-image-digest."
  type        = string
  default     = ""
}

variable "vault_deletion_protection" {
  description = "Deletion protection on the Ansible Vault password secret."
  type        = bool
}

variable "vault_password_version" {
  description = "Bump to rotate the Ansible Vault password."
  type        = number
  default     = 1
}

variable "lb_allowed_members" {
  description = "Identities IAP admits, as IAM members. Supplied as TF_VAR_lb_allowed_members."
  type        = list(string)
}

variable "lb_domain" {
  description = "Domain for a managed certificate, or null for a self-signed one."
  type        = string
  default     = null
}

variable "iap_oauth_client_secret" {
  description = "Secret of the shared IAP OAuth client. Supplied as TF_VAR_iap_oauth_client_secret."
  type        = string
  sensitive   = true
}

variable "iap_oauth_client_secret_version" {
  description = "Bump after rotating the client secret in the console."
  type        = number
  default     = 1
}
