locals {
  ops_vm_service_account = "sa-ops-vm@${var.project_id}.iam.gserviceaccount.com"
  app_vm_service_account = "sa-app-vm@${var.project_id}.iam.gserviceaccount.com"
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

module "cloudsql" {
  source = "../../modules/cloudsql"

  project_id = var.project_id
  region     = var.region

  instance_name      = var.db_instance_name
  network_self_link  = module.network.network_self_link
  allocated_ip_range = module.network.psa_range_name

  database_name    = var.db_name
  app_user_name    = var.db_app_user
  password_version = var.db_password_version

  tier                = var.db_tier
  availability_type   = var.db_availability_type
  deletion_protection = var.db_deletion_protection

  secret_prefix             = var.db_secret_prefix
  app_service_account_email = local.app_vm_service_account

  depends_on = [module.network]
}

module "secrets" {
  source = "../../modules/secrets"

  project_id = var.project_id
  region     = var.region

  secret_prefix             = var.secret_prefix
  ops_service_account_email = local.ops_vm_service_account

  grafana_password_version = var.grafana_password_version
  vault_password_version   = var.vault_password_version
}
