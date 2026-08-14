output "instance_name" {
  description = "Instance name, for gcloud commands and Ansible inventory."
  value       = google_compute_instance.this.name
}

output "zone" {
  description = "Zone the instance runs in, required by every zonal gcloud call."
  value       = google_compute_instance.this.zone
}

output "internal_ip" {
  description = "Internal IP, for Ansible inventory and Prometheus scrape targets."
  value       = google_compute_instance.this.network_interface[0].network_ip
}
