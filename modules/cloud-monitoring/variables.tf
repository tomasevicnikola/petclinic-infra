variable "project_id" {
  description = "GCP project the dashboard and alert policies live in."
  type        = string
}

variable "environment" {
  description = "Environment this dashboard describes. Every filter is scoped to this environment's resources."
  type        = string
}

variable "name_prefix" {
  description = "Prefix the environment's resources are named with, for example petclinic-dev."
  type        = string
}

variable "db_instance_name" {
  description = "Cloud SQL instance name, used to build the database_id filter."
  type        = string
}

variable "cpu_threshold" {
  description = "Instance CPU utilisation, as a fraction, that opens the CPU alert. Measured by the hypervisor, from outside the guest, so a wedged VM cannot suppress it."
  type        = number
  default     = 0.8

  validation {
    condition     = var.cpu_threshold > 0 && var.cpu_threshold <= 1
    error_message = "cpu_threshold is a fraction between 0 and 1, not a percentage."
  }
}

variable "error_rate_threshold" {
  description = "Server errors per second at the load balancer that open the downtime alert."
  type        = number
  default     = 0.1
}

variable "error_alert_duration" {
  description = "How long the error rate must stay above the threshold before the downtime policy opens an incident. Zero on purpose: one 60s window over the threshold is already the signal. On a system this quiet a longer window would hide every real burst, because a burst here lasts seconds, not minutes - and while it lasts, users are being served 500s. CPU and reachability tolerate a transient and keep the longer window."
  type        = string
  default     = "0s"
}

variable "alert_duration" {
  description = "How long a condition must hold before the policy opens an incident."
  type        = string
  default     = "300s"
}

variable "notification_email" {
  description = "Address alerts are emailed to. Empty or null creates no channel and incidents stay in the console. Supplied as TF_VAR_cloud_monitoring_notification_email so it never lands in this public repository."
  type        = string
  default     = null

  validation {
    condition     = var.notification_email == null || can(regex("^$|^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", var.notification_email))
    error_message = "notification_email must be empty or a single email address."
  }
}

variable "lb_host" {
  description = "Hostname the uptime check requests. The sslip.io name while there is no domain, so the Host header matches the certificate's subject."
  type        = string
}

variable "uptime_period" {
  description = "How often Google's probers request the load balancer. 60s is the shortest the API accepts."
  type        = string
  default     = "60s"

  validation {
    condition     = contains(["60s", "300s", "600s", "900s"], var.uptime_period)
    error_message = "uptime_period must be one of 60s, 300s, 600s or 900s."
  }
}
