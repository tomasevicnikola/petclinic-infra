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
