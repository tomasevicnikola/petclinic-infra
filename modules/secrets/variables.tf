variable "project_id" {
  description = "GCP project to create the secrets in."
  type        = string
}

variable "region" {
  description = "Location of the secret replicas."
  type        = string
}

variable "secret_prefix" {
  description = "Prefix for the secrets, which become <prefix>-grafana-admin-password and <prefix>-ansible-vault-password."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,200}$", var.secret_prefix))
    error_message = "secret_prefix may contain only letters, digits, hyphens and underscores."
  }
}

variable "grafana_password_version" {
  description = "Bump to rotate the Grafana admin password. One apply generates a new one and adds a secret version."
  type        = number
  default     = 1

  validation {
    condition     = var.grafana_password_version >= 1
    error_message = "grafana_password_version must be at least 1."
  }
}

variable "vault_password_version" {
  description = "Bump to rotate the Ansible Vault password. Everything encrypted with the old one has to be re-keyed first, so this moves only on purpose."
  type        = number
  default     = 1

  validation {
    condition     = var.vault_password_version >= 1
    error_message = "vault_password_version must be at least 1."
  }
}

variable "ops_service_account_email" {
  description = "Service account of the ops VM, where Ansible runs. Gets secretAccessor on the vault password and nothing else. Created in bootstrap, not here."
  type        = string

  validation {
    condition     = can(regex("^[^@]+@[^.]+\\.iam\\.gserviceaccount\\.com$", var.ops_service_account_email))
    error_message = "ops_service_account_email must be a service account address, not a user account."
  }
}
