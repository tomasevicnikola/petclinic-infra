# Docker registry for the application images the app repo's pipeline builds.
#
# Artifact Registry rather than Container Registry: GCR is deprecated and shut
# down, and gcr.io hosts now redirect into Artifact Registry anyway. Beyond
# being the only option that still gets developed, it is the one that makes
# this repo's IAM shape possible - GCR's permissions were GCS bucket ACLs on
# the whole project, so "this pipeline may write these images and nothing
# else" was not expressible. Artifact Registry has IAM per repository, which
# is exactly the grain sa-cicd needs.

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
  # europe-west3-docker.pkg.dev/petclinic-capstone/petclinic
  #
  # Built here rather than in the environment so the hostname and the path can
  # never drift from the repository they name. The app pipeline appends
  # /<image>:sha-<short> to it.
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

  # The pipeline pushes one image per commit on every pull request, tagged with
  # the short SHA. Nothing ever deletes them by hand, so without a policy the
  # repository grows for the life of the project and the storage bill with it.
  #
  # KEEP beats DELETE when both match an image, which is what makes the pair
  # below safe: the delete rules are written broadly, and the keep rule is the
  # floor they cannot cut through. The most recent images survive however old
  # they are, so a quiet month never empties the repository.
  cleanup_policy_dry_run = var.cleanup_dry_run

  cleanup_policies {
    id     = "keep-recent-tagged"
    action = "KEEP"

    most_recent_versions {
      keep_count = var.keep_tagged_count
    }
  }

  # A failed or superseded build leaves an untagged layer set behind. Nothing
  # references those, so they are pure storage.
  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = "${var.untagged_retention_days * 24}h"
    }
  }

  # Tagged images are per-PR builds, not releases. Old ones go too, except the
  # most recent keep_count that the KEEP rule above protects.
  cleanup_policies {
    id     = "delete-old-tagged"
    action = "DELETE"

    condition {
      tag_state  = "TAGGED"
      older_than = "${var.tagged_retention_days * 24}h"
    }
  }
}

# sa-cicd's first IAM binding anywhere in the project. It was created in
# bootstrap with deliberately zero roles, because until this repository existed
# there was nothing to scope a grant to and a project-level
# roles/artifactregistry.writer would have covered every repository that will
# ever be created here. This is that grant, on this one repository.
#
# writer, not admin: the pipeline pushes and pulls images. Deleting them is the
# cleanup policy's job, and changing who may push is this file's.
resource "google_artifact_registry_repository_iam_member" "cicd_writer" {
  project    = var.project_id
  location   = google_artifact_registry_repository.this.location
  repository = google_artifact_registry_repository.this.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.cicd_service_account_email}"
}
