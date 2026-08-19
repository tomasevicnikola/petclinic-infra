variable "project_id" {
  description = "GCP project to create the repository in."
  type        = string
}

variable "region" {
  description = "Location of the repository. Also the first label of its hostname, <region>-docker.pkg.dev, so moving it moves every image reference."
  type        = string
}

variable "repository_id" {
  description = "Name of the repository, and the last path segment of the registry URL."
  type        = string
  default     = "petclinic"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.repository_id))
    error_message = "repository_id must be lowercase letters, digits and hyphens, starting and ending with a letter or digit."
  }
}

variable "description" {
  description = "Shown in the console next to the repository."
  type        = string
  default     = "Application container images, pushed by the app repository's pipeline."
}

variable "cicd_service_account_email" {
  description = "Service account the app repository's pipeline federates into. Gets artifactregistry.writer on this repository and nothing else. Created in bootstrap, not here."
  type        = string

  validation {
    condition     = can(regex("^[^@]+@[^.]+\\.iam\\.gserviceaccount\\.com$", var.cicd_service_account_email))
    error_message = "cicd_service_account_email must be a service account address, not a user account."
  }
}

variable "keep_tagged_count" {
  description = "How many of the most recent images survive regardless of age. The floor the delete rules cannot cut through, so it is also how far back a rollback can reach."
  type        = number
  default     = 10

  validation {
    condition     = var.keep_tagged_count >= 1
    error_message = "keep_tagged_count must be at least 1."
  }
}

variable "untagged_retention_days" {
  description = "How long an untagged image lives. These are leftovers from failed or superseded builds that nothing references."
  type        = number
  default     = 7

  validation {
    condition     = var.untagged_retention_days >= 1
    error_message = "untagged_retention_days must be at least 1."
  }
}

variable "tagged_retention_days" {
  description = "How long a tagged image lives once it is older than the most recent keep_tagged_count. These are per-PR builds, not releases."
  type        = number
  default     = 30

  validation {
    condition     = var.tagged_retention_days >= 1
    error_message = "tagged_retention_days must be at least 1."
  }
}

variable "cleanup_dry_run" {
  description = "Runs the cleanup policies without deleting anything, logging what they would have removed. True is how you check a policy change before trusting it with images."
  type        = bool
  default     = false
}
