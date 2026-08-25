output "network_id" {
  description = "VPC id."
  value       = module.stack.network_id
}

output "network_self_link" {
  description = "VPC self link."
  value       = module.stack.network_self_link
}

output "subnet_id" {
  description = "Subnet id."
  value       = module.stack.subnet_id
}

output "subnet_self_link" {
  description = "Subnet self link."
  value       = module.stack.subnet_self_link
}

output "psa_range_name" {
  description = "Reserved Private Service Access range."
  value       = module.stack.psa_range_name
}

output "ops_vm_name" {
  description = "Ops instance name. Null where the environment does not create one."
  value       = module.stack.ops_vm_name
}

output "ops_vm_zone" {
  description = "Ops instance zone. Null where the environment does not create one."
  value       = module.stack.ops_vm_zone
}

output "ops_vm_internal_ip" {
  description = "Ops instance internal IP. Null where the environment does not create one."
  value       = module.stack.ops_vm_internal_ip
}

output "db_instance_name" {
  description = "Cloud SQL instance name."
  value       = module.stack.db_instance_name
}

output "db_connection_name" {
  description = "Cloud SQL connection name."
  value       = module.stack.db_connection_name
}

output "db_private_ip" {
  description = "Private IP of the database."
  value       = module.stack.db_private_ip
}

output "db_name" {
  description = "Application database name."
  value       = module.stack.db_name
}

output "db_app_user" {
  description = "MySQL user the application connects as."
  value       = module.stack.db_app_user
}

output "db_password_secret_id" {
  description = "Secret holding the application user's password."
  value       = module.stack.db_password_secret_id
}

output "db_config_secret_id" {
  description = "Secret holding the database connection details as JSON."
  value       = module.stack.db_config_secret_id
}

output "ansible_vault_secret_id" {
  description = "Secret holding the Ansible Vault password."
  value       = module.stack.ansible_vault_secret_id
}

output "grafana_admin_secret_id" {
  description = "Secret holding Grafana's admin password. Null where no ops VM, and therefore no monitoring stack, exists."
  value       = module.stack.grafana_admin_secret_id
}

output "app_instance_group" {
  description = "Managed instance group self link."
  value       = module.stack.app_instance_group
}

output "app_instance_group_manager_name" {
  description = "Group manager name."
  value       = module.stack.app_instance_group_manager_name
}

output "app_health_check_self_link" {
  description = "Health check self link."
  value       = module.stack.app_health_check_self_link
}

output "app_named_port" {
  description = "Named port the load balancer backend references."
  value       = module.stack.app_named_port
}

output "lb_ip" {
  description = "Public IP of the load balancer."
  value       = module.stack.lb_ip
}

output "lb_url" {
  description = "URL the load balancer answers on."
  value       = module.stack.lb_url
}

output "lb_backend_service_name" {
  description = "Backend service name."
  value       = module.stack.lb_backend_service_name
}

output "registry_url" {
  description = "Registry path images are tagged with. Null where the environment does not create the repository."
  value       = module.stack.registry_url
}

output "registry_host" {
  description = "Registry hostname. Null where the environment does not create the repository."
  value       = module.stack.registry_host
}

output "registry_repository_id" {
  description = "Docker repository name. Null where the environment does not create the repository."
  value       = module.stack.registry_repository_id
}

output "cloud_monitoring_dashboard_id" {
  description = "Cloud Monitoring dashboard for this environment."
  value       = module.stack.cloud_monitoring_dashboard_id
}

output "cloud_monitoring_alert_policies" {
  description = "Alert policies created in Cloud Monitoring."
  value       = module.stack.cloud_monitoring_alert_policies
}
