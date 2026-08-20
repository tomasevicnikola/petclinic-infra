terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

locals {
  registry_url = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.this.repository_id}"
}

resource "google_artifact_registry_repository" "this" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  description   = var.description
  format        = "DOCKER"

  labels = {
    component  = "cicd"
    managed-by = "terraform"
  }

  cleanup_policy_dry_run = var.cleanup_dry_run

  cleanup_policies {
    id     = "keep-recent-versions"
    action = "KEEP"

    most_recent_versions {
      keep_count = var.keep_recent_count
    }
  }

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = "${var.untagged_retention_days * 24}h"
    }
  }

  cleanup_policies {
    id     = "delete-old-tagged"
    action = "DELETE"

    condition {
      tag_state  = "TAGGED"
      older_than = "${var.tagged_retention_days * 24}h"
    }
  }
}

resource "google_artifact_registry_repository_iam_member" "cicd_writer" {
  project    = var.project_id
  location   = google_artifact_registry_repository.this.location
  repository = google_artifact_registry_repository.this.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.cicd_service_account_email}"
}
