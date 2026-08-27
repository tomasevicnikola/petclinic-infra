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
  description = "Machine type. e2-medium is the smallest dedicated-core option: shared-core types (e2-small, e2-micro) earn and spend CPU burst credits, so cpu_utilization is not linear in the work done and an autoscaler reading it is miscalibrated by construction. Measured on e2-small, a booting instance reported 160-180% cpu_utilization."
  type        = string
  default     = "e2-medium"
}

variable "app_image" {
  description = "Image the instances boot from, as a self link or an image family reference. Null tracks the petclinic-app family in this project, so the newest bake reaches the next rolling replace on its own. Set an exact image self link to pin a version, which is what makes a rollback reproducible."
  type        = string
  default     = null
}

variable "app_image_digest" {
  description = "Digest of the application container the instances run, read from instance metadata at boot. This is the deployed version: changing it replaces the template and rolls the group onto it."
  type        = string

  validation {
    condition     = can(regex("^sha256:[0-9a-f]{64}$", var.app_image_digest))
    error_message = "app_image_digest must be a sha256 digest, for example sha256:abc123... A tag is not acceptable: tags move, and an instance that boots a week later would get a different image."
  }
}

variable "app_env" {
  description = "Environment name the instances belong to, passed as metadata. The baked run script derives its Secret Manager names from it, which is what lets one image serve every environment."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,15}$", var.app_env))
    error_message = "app_env must be a short lowercase environment name, for example dev."
  }
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
  description = "Whether the group replaces instances that fail the autohealing health check. Safe now that instances boot from a baked image and serve on their own: before, an instance arrived with no application on it and would have been recreated forever."
  type        = bool
  default     = true
}

variable "autohealing_initial_delay_sec" {
  description = "Grace period after an instance boots before the autohealing check counts against it. Also gates the rolling update, so it sets the floor on how long a deploy takes. Measured creation to serving is 56-121s over four deploys; autohealing then needs a further 5 failed checks at 30s on top of this delay, so nothing is replaced before 300s at this value - roughly 2.5x the slowest boot observed."
  type        = number
  default     = 150

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
  description = "How long a new instance is ignored by the autoscaler. Must outlast boot and startup, or the CPU spent getting ready reads as load and scales the group again. Unchanged at 120s, but a baked instance is serving in 60-90s, so this now has margin instead of expiring mid-boot."
  type        = number
  default     = 120

  validation {
    condition     = var.cooldown_period_sec >= 15
    error_message = "cooldown_period_sec must be at least 15."
  }
}
