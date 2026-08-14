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
