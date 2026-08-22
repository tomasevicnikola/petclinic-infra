variable "project_id" {
  description = "GCP project to create the load balancer in."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for every resource here. Set per environment, so no default."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]{0,30}[a-z0-9])?$", var.name_prefix))
    error_message = "name_prefix must be a lowercase RFC1035 name, short enough to leave room for the suffixes."
  }
}

variable "allowed_members" {
  description = "Identities IAP admits, as IAM member strings. Everyone else is turned away at the edge before a request reaches a backend, which is what keeps a public load balancer off the public Internet. No default on purpose."
  type        = list(string)

  validation {
    condition     = length(var.allowed_members) > 0
    error_message = "allowed_members must list at least one identity; an empty list would lock everyone out including you."
  }

  validation {
    condition     = !contains(var.allowed_members, "allUsers") && !contains(var.allowed_members, "allAuthenticatedUsers")
    error_message = "allowed_members must not contain allUsers or allAuthenticatedUsers, which would defeat the point."
  }

  validation {
    condition     = alltrue([for m in var.allowed_members : can(regex("^(user|group|serviceAccount|domain):", m))])
    error_message = "every entry must be an IAM member string, for example user:someone@example.com."
  }
}

variable "instance_group" {
  description = "Instance group the backend sends traffic to, from the compute-mig module."
  type        = string
}

variable "health_check_self_link" {
  description = "Health check the backend uses, from the compute-mig module. Shared on purpose: the load balancer and the group ask the same question, so a second check would only be a second thing to keep in sync."
  type        = string
}

variable "port_name" {
  description = "Named port on the instance group the backend targets. Must match what the group publishes."
  type        = string
  default     = "http"
}

variable "domain" {
  description = "Domain for a Google-managed certificate. Null means no domain exists yet, so the module issues a self-signed certificate instead and browsers will warn."
  type        = string
  default     = null
}

variable "self_signed_validity_hours" {
  description = "Lifetime of the self-signed certificate. Only used when domain is null."
  type        = number
  default     = 8760

  validation {
    condition     = var.self_signed_validity_hours >= 24
    error_message = "self_signed_validity_hours must be at least 24."
  }
}

variable "backend_timeout_sec" {
  description = "How long the backend may take to answer before the load balancer gives up."
  type        = number
  default     = 30

  validation {
    condition     = var.backend_timeout_sec > 0 && var.backend_timeout_sec <= 3600
    error_message = "backend_timeout_sec must be between 1 and 3600."
  }
}

variable "max_utilization" {
  description = "Backend utilisation the balancer aims for before spreading load further."
  type        = number
  default     = 0.8

  validation {
    condition     = var.max_utilization > 0 && var.max_utilization <= 1
    error_message = "max_utilization must be between 0 and 1."
  }
}

variable "log_sample_rate" {
  description = "Fraction of requests written to the load balancer logs. These are what the monitoring phase reads, and what shows a Cloud Armor denial."
  type        = number
  default     = 0.5

  validation {
    condition     = var.log_sample_rate >= 0 && var.log_sample_rate <= 1
    error_message = "log_sample_rate must be between 0 and 1."
  }
}

variable "iap_oauth_client_id" {
  description = "OAuth 2.0 client IAP authenticates against. Created by hand in the console; a Google-managed client would admit only identities internal to the organization."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+-[a-z0-9]+\\.apps\\.googleusercontent\\.com$", var.iap_oauth_client_id))
    error_message = "iap_oauth_client_id must look like 123456789-abc123def456.apps.googleusercontent.com."
  }
}

variable "iap_oauth_client_secret" {
  description = "Secret of iap_oauth_client_id. Sensitive hides it from CLI output but not from state: the backend service attribute that consumes it is not write-only."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.iap_oauth_client_secret) > 0
    error_message = "iap_oauth_client_secret must not be empty; IAP rejects a client id with no secret."
  }
}
