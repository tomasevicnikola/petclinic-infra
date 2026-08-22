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

variable "lb_name_prefix" {
  description = "Prefix for the load balancer, its IP, policy, proxies and forwarding rules."
  type        = string
  default     = "petclinic-dev-lb"
}

variable "lb_allowed_members" {
  description = "Identities IAP admits to the dev load balancer, as IAM members. No default on purpose: this is the whole access control list, and the resources are per-member, so a value that merely looks safe is not safe. ['user:nobody@example.com'] would not fail closed - it would delete the grants that exist and lock the environment out of itself. An unset variable has to stop the run instead, which is what having no default does."
  type        = list(string)
}

variable "iap_oauth_client_id" {
  description = "OAuth 2.0 client IAP authenticates against, created by hand in the console. Not a secret, so it is committed rather than passed in out-of-band."
  type        = string
  default     = "923128095631-v96nc3sies5njkaghoublmacb74nmesr.apps.googleusercontent.com"
}

variable "iap_oauth_client_secret" {
  description = "Secret of iap_oauth_client_id, supplied as TF_VAR_iap_oauth_client_secret from the IAP_OAUTH_CLIENT_SECRET Actions secret. Persisted in the state file - see modules/load-balancer/README.md."
  type        = string
  sensitive   = true
}

variable "iap_oauth_client_secret_version" {
  description = "Bump together with a rotation of the client secret in the console."
  type        = number
  default     = 1
}

variable "lb_domain" {
  description = "Domain for a managed certificate. Null while no domain exists, which makes the module issue a self-signed one."
  type        = string
  default     = null
}

variable "app_port" {
  description = "Port the application listens on. One value for the whole environment: the firewall opens it to health checkers and the group publishes it as its named port, so they cannot drift apart."
  type        = number
  default     = 8080
}

variable "app_name_prefix" {
  description = "Prefix for the application group, its template, health check and autoscaler."
  type        = string
  default     = "petclinic-dev-app"
}

variable "app_machine_type" {
  description = "Machine type of the application instances."
  type        = string
  default     = "e2-small"
}

variable "app_min_replicas" {
  description = "Smallest the dev group scales to."
  type        = number
  default     = 2
}

variable "app_max_replicas" {
  description = "Largest the dev group scales to, and the cost stop."
  type        = number
  default     = 4
}

variable "app_cpu_target" {
  description = "Average CPU the autoscaler holds across the dev group."
  type        = number
  default     = 0.6
}

variable "app_enable_autohealing" {
  description = "Autohealing on the dev group. False until the deploy pipeline puts the application on the instances; a health check against an empty instance would recreate it forever."
  type        = bool
  default     = false
}

variable "env_prefix" {
  description = "Prefix of the cross-cutting dev secrets: dev-ansible-vault-password."
  type        = string
  default     = "dev"
}

variable "vault_deletion_protection" {
  description = "Deletion protection on the Ansible Vault password secret. Tearing dev down means setting this to false, applying, and then destroying."
  type        = bool
  default     = true
}

variable "vault_password_version" {
  description = "Bump to rotate the dev Ansible Vault password. Re-key everything encrypted with the old one first."
  type        = number
  default     = 1
}

variable "registry_repository_id" {
  description = "Name of the dev Docker repository, and the last segment of the registry URL the app pipeline tags against."
  type        = string
  default     = "petclinic"
}

variable "registry_keep_recent_count" {
  description = "How many of the most recent dev versions survive the cleanup policy regardless of age, tagged or not. Bounds how far back a rollback can reach."
  type        = number
  default     = 10
}

variable "registry_cleanup_dry_run" {
  description = "Runs the dev cleanup policies without deleting anything, logging what they would have removed. True is how a policy change gets checked before it is trusted with images."
  type        = bool
  default     = false
}

variable "registry_untagged_retention_days" {
  description = "How long untagged dev images live. Leftovers from failed or superseded builds, referenced by nothing."
  type        = number
  default     = 7
}

variable "registry_tagged_retention_days" {
  description = "How long a tagged dev image lives once it falls out of the most recent registry_keep_recent_count."
  type        = number
  default     = 30
}
