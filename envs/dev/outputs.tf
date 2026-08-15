output "network_id" {
  description = "VPC id."
  value       = module.network.network_id
}

output "network_self_link" {
  description = "VPC self link."
  value       = module.network.network_self_link
}

output "subnet_id" {
  description = "Subnet id."
  value       = module.network.subnet_id
}

output "subnet_self_link" {
  description = "Subnet self link."
  value       = module.network.subnet_self_link
}

output "psa_range_name" {
  description = "Reserved Private Service Access range, consumed by Cloud SQL."
  value       = module.network.psa_range_name
}

output "ops_vm_name" {
  description = "Ops instance name."
  value       = module.ops_vm.instance_name
}

output "ops_vm_zone" {
  description = "Ops instance zone."
  value       = module.ops_vm.zone
}

output "ops_vm_internal_ip" {
  description = "Ops instance internal IP."
  value       = module.ops_vm.internal_ip
}

output "db_instance_name" {
  description = "Cloud SQL instance name."
  value       = module.cloudsql.instance_name
}

output "db_connection_name" {
  description = "Cloud SQL connection name, project:region:instance."
  value       = module.cloudsql.connection_name
}

output "db_private_ip" {
  description = "Private IP of the database, for the instance template and Ansible."
  value       = module.cloudsql.private_ip_address
}

output "db_name" {
  description = "Application database name."
  value       = module.cloudsql.database_name
}

output "db_app_user" {
  description = "MySQL user the application connects as."
  value       = module.cloudsql.app_user_name
}

output "db_password_secret_id" {
  description = "Secret holding the application user's password. The id only."
  value       = module.cloudsql.password_secret_id
}

output "db_config_secret_id" {
  description = "Secret holding the database connection details as JSON."
  value       = module.cloudsql.config_secret_id
}
