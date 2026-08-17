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

variable "allowed_source_ranges" {
  description = "Source CIDRs Cloud Armor lets through. Everything else gets 403 at the edge, which is what keeps a public load balancer off the public Internet. No default on purpose."
  type        = list(string)

  validation {
    condition     = length(var.allowed_source_ranges) > 0
    error_message = "allowed_source_ranges must list at least one CIDR; an empty list would deny everything including you."
  }

  validation {
    condition     = !contains(var.allowed_source_ranges, "0.0.0.0/0") && !contains(var.allowed_source_ranges, "::/0")
    error_message = "allowed_source_ranges must not contain 0.0.0.0/0 or ::/0, which would defeat the policy."
  }

  validation {
    condition     = alltrue([for c in var.allowed_source_ranges : can(cidrhost(c, 0))])
    error_message = "every entry must be a valid CIDR, for example 203.0.113.7/32."
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
