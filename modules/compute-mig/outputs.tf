output "instance_group" {
  description = "Self link of the managed instance group, which is what a load balancer backend service takes."
  value       = google_compute_region_instance_group_manager.this.instance_group
}

output "instance_group_manager_name" {
  description = "Group manager name, for gcloud commands and Ansible inventory."
  value       = google_compute_region_instance_group_manager.this.name
}

output "health_check_self_link" {
  description = "Self link of the load balancer's health check: fast, so a bad backend leaves the pool quickly. Autohealing deliberately uses a different, slower one."
  value       = google_compute_health_check.this.self_link
}

output "autohealing_health_check_self_link" {
  description = "Self link of the autohealing check. Slower and more forgiving than the load balancer's, so a redeploy is not mistaken for a dead instance."
  value       = google_compute_health_check.autohealing.self_link
}

output "instance_template_name" {
  description = "Current instance template. Changes on every template edit, since templates are immutable."
  value       = google_compute_instance_template.this.name
}

output "named_port" {
  description = "Named port the load balancer backend must reference."
  value       = "http"
}
