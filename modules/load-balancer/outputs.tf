output "lb_ip" {
  description = "Public IP of the load balancer. The only public address in the project."
  value       = google_compute_global_address.this.address
}

output "url" {
  description = "URL the load balancer answers on."
  value       = "https://${local.host}"
}

output "sslip_host" {
  description = "sslip.io name that resolves to the load balancer IP, useful while there is no real domain."
  value       = local.sslip_host
}

output "backend_service_name" {
  description = "Backend service name, for checking backend health."
  value       = google_compute_backend_service.this.name
}
