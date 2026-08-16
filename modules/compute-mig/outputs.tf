output "instance_group" {
  description = "Self link of the managed instance group, which is what a load balancer backend service takes."
  value       = google_compute_region_instance_group_manager.this.instance_group
}

output "instance_group_manager_name" {
  description = "Group manager name, for gcloud commands and Ansible inventory."
  value       = google_compute_region_instance_group_manager.this.name
}

output "health_check_self_link" {
  description = "Health check self link. The group only uses it when autohealing is on; the load balancer will use it too."
  value       = google_compute_health_check.this.self_link
}

output "instance_template_name" {
  description = "Current instance template. Changes on every template edit, since templates are immutable."
  value       = google_compute_instance_template.this.name
}

output "named_port" {
  description = "Named port the load balancer backend must reference."
  value       = "http"
}
