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

output "ansible_vault_secret_id" {
  description = "Secret holding the Ansible Vault password. The id only."
  value       = module.secrets.ansible_vault_secret_id
}

output "app_instance_group" {
  description = "Managed instance group self link, for the load balancer backend service."
  value       = module.compute_mig.instance_group
}

output "app_instance_group_manager_name" {
  description = "Group manager name, for gcloud and Ansible inventory."
  value       = module.compute_mig.instance_group_manager_name
}

output "app_health_check_self_link" {
  description = "Health check self link, reused by the load balancer."
  value       = module.compute_mig.health_check_self_link
}

output "app_named_port" {
  description = "Named port the load balancer backend must reference."
  value       = module.compute_mig.named_port
}

output "lb_ip" {
  description = "Public IP of the load balancer, the only public address in the project."
  value       = module.load_balancer.lb_ip
}

output "lb_url" {
  description = "URL the load balancer answers on."
  value       = module.load_balancer.url
}

output "lb_backend_service_name" {
  description = "Backend service name, for checking backend health."
  value       = module.load_balancer.backend_service_name
}
