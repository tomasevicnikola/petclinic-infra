variable "project_id" {
  description = "GCP project that owns every resource in this environment."
  type        = string
  default     = "petclinic-capstone"
}

variable "region" {
  description = "Default region for regional resources."
  type        = string
  default     = "europe-west3"
}

variable "zone" {
  description = "Default zone for zonal resources."
  type        = string
  default     = "europe-west3-a"
}

variable "network_name" {
  description = "Name of the dev VPC."
  type        = string
  default     = "petclinic-dev-vpc"
}

variable "subnet_name" {
  description = "Name of the dev subnet."
  type        = string
  default     = "petclinic-dev-subnet"
}

variable "subnet_cidr" {
  description = "Primary IPv4 range of the dev subnet."
  type        = string
  default     = "10.10.0.0/24"

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "subnet_cidr must be a valid IPv4 CIDR block."
  }
}

variable "psa_cidr" {
  description = "Range reserved for Private Service Access peering in dev."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/(1[6-9]|2[0-4])$", var.psa_cidr)) && can(cidrhost(var.psa_cidr, 0))
    error_message = "psa_cidr must be a valid IPv4 CIDR with a prefix between /16 and /24."
  }
}

variable "ops_vm_name" {
  description = "Name of the dev ops instance."
  type        = string
  default     = "petclinic-dev-ops"
}

variable "db_instance_name" {
  description = "Name of the dev Cloud SQL instance. Cloud SQL holds a deleted name for about a week, so recreating needs a new one."
  type        = string
  default     = "petclinic-dev-mysql"
}

variable "db_name" {
  description = "Application database on the dev instance."
  type        = string
  default     = "petclinic"
}

variable "db_app_user" {
  description = "MySQL user the application connects as in dev."
  type        = string
  default     = "petclinic"
}

variable "db_password_version" {
  description = "Bump to rotate the dev database password. The MySQL user and the secret change together in one apply."
  type        = number
  default     = 1
}

variable "db_tier" {
  description = "Machine tier of the dev instance."
  type        = string
  default     = "db-g1-small"
}

variable "db_availability_type" {
  description = "ZONAL in dev. Prod would be REGIONAL."
  type        = string
  default     = "ZONAL"
}

variable "db_deletion_protection" {
  description = "Deletion protection on the dev database, in Terraform and in the API. Tearing dev down means setting this to false, applying, and then destroying."
  type        = bool
  default     = true
}

variable "db_secret_prefix" {
  description = "Prefix of the dev database secrets: dev-db-app-password and dev-db-app-config."
  type        = string
  default     = "dev-db-app"
}

