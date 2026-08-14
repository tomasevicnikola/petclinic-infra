variable "project_id" {
  description = "GCP project to create the network in."
  type        = string
}

variable "region" {
  description = "Region for the subnet, router and NAT."
  type        = string
}

variable "network_name" {
  description = "Name of the VPC. Every other resource in this module is named after it."
  type        = string
  default     = "petclinic-vpc"
}

variable "subnet_name" {
  description = "Name of the single regional subnet that holds all VMs."
  type        = string
  default     = "petclinic-subnet"
}

variable "subnet_cidr" {
  description = "Primary IPv4 range of the subnet, in CIDR notation."
  type        = string
  default     = "10.10.0.0/24"

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "subnet_cidr must be a valid IPv4 CIDR block, for example 10.10.0.0/24."
  }
}

variable "psa_cidr" {
  description = "Range reserved for Private Service Access peering, consumed by Cloud SQL later."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/(1[6-9]|2[0-4])$", var.psa_cidr)) && can(cidrhost(var.psa_cidr, 0))
    error_message = "psa_cidr must be a valid IPv4 CIDR with a prefix between /16 and /24, for example 10.20.0.0/16."
  }
}

variable "app_port" {
  description = "TCP port the application listens on, opened to load balancer health checks."
  type        = number
  default     = 8080

  validation {
    condition     = var.app_port > 0 && var.app_port < 65536
    error_message = "app_port must be a valid TCP port."
  }
}

variable "node_exporter_port" {
  description = "TCP port scraped by Prometheus on application and ops VMs."
  type        = number
  default     = 9100

  validation {
    condition     = var.node_exporter_port > 0 && var.node_exporter_port < 65536
    error_message = "node_exporter_port must be a valid TCP port."
  }
}
