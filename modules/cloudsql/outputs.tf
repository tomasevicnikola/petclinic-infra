output "instance_name" {
  description = "Instance name, for gcloud sql commands."
  value       = google_sql_database_instance.this.name
}

output "connection_name" {
  description = "project:region:instance, the identifier the Cloud SQL Auth Proxy and gcloud take."
  value       = google_sql_database_instance.this.connection_name
}

output "private_ip_address" {
  description = "Private IP inside the PSA range. The only address the instance has."
  value       = google_sql_database_instance.this.private_ip_address
}

output "database_name" {
  description = "Application database on the instance."
  value       = google_sql_database.this.name
}

output "app_user_name" {
  description = "MySQL user the application connects as. The password is in Secret Manager, never here."
  value       = google_sql_user.app.name
}

output "password_secret_id" {
  description = "Secret holding the application user's password. The id, not the payload."
  value       = google_secret_manager_secret.app_password.secret_id
}

output "config_secret_id" {
  description = "Secret holding host, port, database and username as JSON."
  value       = google_secret_manager_secret.app_config.secret_id
}
