variable "project_id" {
  description = "GCP project to create the instance in."
  type        = string
}

variable "zone" {
  description = "Zone for the instance."
  type        = string
}

variable "instance_name" {
  description = "Name of the ops instance. Set per environment, so no default."
  type        = string
}

variable "machine_type" {
  description = "Machine type. e2-small holds a runner plus a small compose stack; raise it when the monitoring stack lands."
  type        = string
  default     = "e2-small"
}

variable "boot_image" {
  description = "Boot image or image family for the instance."
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB. Docker images and runner work directories live here."
  type        = number
  default     = 30

  validation {
    condition     = var.boot_disk_size_gb >= 10
    error_message = "boot_disk_size_gb must be at least 10."
  }
}

variable "subnet_id" {
  description = "Subnet the instance attaches to, from the network module."
  type        = string
}

variable "service_account_email" {
  description = "Service account attached to the instance. Created in bootstrap, not here."
  type        = string

  validation {
    condition     = can(regex("^[^@]+@[^.]+\\.iam\\.gserviceaccount\\.com$", var.service_account_email))
    error_message = "service_account_email must be a service account address, not a user account."
  }
}

variable "network_tags" {
  description = "Network tags the firewall rules match on. Must match the network module's tags."
  type        = list(string)
  default     = ["ssh-iap", "ops"]
}
