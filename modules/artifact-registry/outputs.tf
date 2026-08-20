output "repository_id" {
  description = "Repository name, for gcloud artifacts commands."
  value       = google_artifact_registry_repository.this.repository_id
}

output "registry_url" {
  description = "Registry path images are tagged with, <region>-docker.pkg.dev/<project>/<repository>. The pipeline appends /<image>:<tag>."
  value       = local.registry_url
}

output "registry_host" {
  description = "Registry hostname on its own, the argument to gcloud auth configure-docker."
  value       = "${var.region}-docker.pkg.dev"
}
