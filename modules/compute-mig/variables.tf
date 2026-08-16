variable "project_id" {
  description = "GCP project to create the group in."
  type        = string
}

variable "region" {
  description = "Region for the group and the autoscaler. Instances spread across every zone it has."
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

variable "machine_type" {
  description = "Machine type. e2-small fits a JVM in a container with room for the agent; the app is memory bound before it is CPU bound, so raise this before raising replica counts."
  type        = string
  default     = "e2-small"
}

variable "boot_image" {
  description = "Boot image or image family for the instances."
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB. Holds the OS and the application image."
  type        = number
  default     = 20

  validation {
    condition     = var.boot_disk_size_gb >= 10
    error_message = "boot_disk_size_gb must be at least 10."
  }
}

variable "subnet_id" {
  description = "Subnet the instances attach to, from the network module."
  type        = string
}

variable "service_account_email" {
  description = "Service account attached to the instances. Created in bootstrap, not here."
  type        = string

  validation {
    condition     = can(regex("^[^@]+@[^.]+\\.iam\\.gserviceaccount\\.com$", var.service_account_email))
    error_message = "service_account_email must be a service account address, not a user account."
  }
}

variable "network_tags" {
  description = "Network tags the firewall rules match on. Must match the network module's tags, or health checks and IAP SSH will not reach the instances."
  type        = list(string)
  default     = ["ssh-iap", "app"]
}

variable "base_instance_name" {
  description = "Prefix the group gives each instance, followed by a random suffix. Falls back to name_prefix, so instances carry the environment like every other resource here."
  type        = string
  default     = null
}

variable "app_port" {
  description = "Port the application listens on. Also the named port the load balancer will target."
  type        = number
  default     = 8080

  validation {
    condition     = var.app_port > 0 && var.app_port < 65536
    error_message = "app_port must be a valid TCP port."
  }
}

variable "health_check_path" {
  description = "HTTP path the health check requests. Spring Boot Actuator exposes this once the app runs."
  type        = string
  default     = "/actuator/health"
}

variable "enable_autohealing" {
  description = "Whether the group replaces instances that fail the health check. False until the deploy pipeline exists, because an instance with no application on it fails the check by definition and would be recreated forever."
  type        = bool
  default     = false
}

variable "autohealing_initial_delay_sec" {
  description = "Grace period after an instance boots before health checks count against it. Has to cover boot, image pull and JVM start."
  type        = number
  default     = 300

  validation {
    condition     = var.autohealing_initial_delay_sec >= 0 && var.autohealing_initial_delay_sec <= 3600
    error_message = "autohealing_initial_delay_sec must be between 0 and 3600."
  }
}

variable "max_surge" {
  description = "Extra instances a rolling update may add. A regional group needs at least one per zone, so this cannot be lower than the number of zones in the region."
  type        = number
  default     = 3

  validation {
    condition     = var.max_surge >= 1
    error_message = "max_surge must be at least 1."
  }
}

variable "min_replicas" {
  description = "Floor for the autoscaler. Two so a single instance failing never means zero serving."
  type        = number
  default     = 2

  validation {
    condition     = var.min_replicas >= 1
    error_message = "min_replicas must be at least 1."
  }
}

variable "max_replicas" {
  description = "Ceiling for the autoscaler, and the cost stop."
  type        = number
  default     = 4

  validation {
    condition     = var.max_replicas >= var.min_replicas
    error_message = "max_replicas must be greater than or equal to min_replicas."
  }
}

variable "cpu_target" {
  description = "Average CPU the autoscaler aims to hold across the group."
  type        = number
  default     = 0.6

  validation {
    condition     = var.cpu_target > 0 && var.cpu_target <= 1
    error_message = "cpu_target must be between 0 and 1."
  }
}

variable "cooldown_period_sec" {
  description = "How long a new instance is ignored by the autoscaler. Must outlast boot and startup, or the CPU spent installing updates reads as load and scales the group again."
  type        = number
  default     = 120

  validation {
    condition     = var.cooldown_period_sec >= 15
    error_message = "cooldown_period_sec must be at least 15."
  }
}
