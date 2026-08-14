locals {
  ops_vm_service_account = "sa-ops-vm@${var.project_id}.iam.gserviceaccount.com"
}

module "network" {
  source = "../../modules/network"

  project_id = var.project_id
  region     = var.region

  network_name = var.network_name
  subnet_name  = var.subnet_name
  subnet_cidr  = var.subnet_cidr
  psa_cidr     = var.psa_cidr
}

module "ops_vm" {
  source = "../../modules/ops-vm"

  project_id = var.project_id
  zone       = var.zone

  instance_name         = var.ops_vm_name
  subnet_id             = module.network.subnet_id
  service_account_email = local.ops_vm_service_account

  network_tags = [module.network.tags.ssh_iap, module.network.tags.ops]
}
