output "network_id" {
  description = "VPC id, for resources that take a network reference."
  value       = google_compute_network.this.id
}

output "network_self_link" {
  description = "VPC self link, for APIs that require the full URL."
  value       = google_compute_network.this.self_link
}

output "subnet_id" {
  description = "Subnet id, for instance templates and load balancer components."
  value       = google_compute_subnetwork.this.id
}

output "subnet_self_link" {
  description = "Subnet self link, for APIs that require the full URL."
  value       = google_compute_subnetwork.this.self_link
}

output "psa_range_name" {
  description = "Name of the reserved peering range, needed when Cloud SQL attaches to it."
  value       = google_compute_global_address.psa.name
}

output "tags" {
  description = "Network tags the firewall rules match on. Instance templates must use these."
  value       = local.tags
}
