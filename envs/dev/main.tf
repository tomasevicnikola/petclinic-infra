locals {
  ops_vm_service_account = "sa-ops-vm@${var.project_id}.iam.gserviceaccount.com"
  app_vm_service_account = "sa-app-vm@${var.project_id}.iam.gserviceaccount.com"
  cicd_service_account   = "sa-cicd@${var.project_id}.iam.gserviceaccount.com"
}

module "network" {
  source = "../../modules/network"

  project_id = var.project_id
  region     = var.region

  network_name = var.network_name
  subnet_name  = var.subnet_name
  subnet_cidr  = var.subnet_cidr
  psa_cidr     = var.psa_cidr
  app_port     = var.app_port
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

module "compute_mig" {
  source = "../../modules/compute-mig"

  project_id = var.project_id
  region     = var.region

  name_prefix           = var.app_name_prefix
  subnet_id             = module.network.subnet_id
  service_account_email = local.app_vm_service_account

  network_tags = [module.network.tags.ssh_iap, module.network.tags.app]
  app_port     = var.app_port

  machine_type = var.app_machine_type
  min_replicas = var.app_min_replicas
  max_replicas = var.app_max_replicas
  cpu_target   = var.app_cpu_target

  enable_autohealing = var.app_enable_autohealing
}

module "load_balancer" {
  source = "../../modules/load-balancer"

  project_id  = var.project_id
  name_prefix = var.lb_name_prefix

  instance_group         = module.compute_mig.instance_group
  health_check_self_link = module.compute_mig.health_check_self_link
  port_name              = module.compute_mig.named_port

  allowed_members = var.lb_allowed_members
  domain          = var.lb_domain

  iap_oauth_client_id     = var.iap_oauth_client_id
  iap_oauth_client_secret = var.iap_oauth_client_secret
}

module "secrets" {
  source = "../../modules/secrets"

  project_id = var.project_id
  region     = var.region

  env_prefix                = var.env_prefix
  ops_service_account_email = local.ops_vm_service_account

  vault_password_version    = var.vault_password_version
  vault_deletion_protection = var.vault_deletion_protection

  iap_oauth_client_secret         = var.iap_oauth_client_secret
  iap_oauth_client_secret_version = var.iap_oauth_client_secret_version
}

module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id = var.project_id
  region     = var.region

  repository_id = var.registry_repository_id

  cicd_service_account_email = local.cicd_service_account

  keep_recent_count       = var.registry_keep_recent_count
  untagged_retention_days = var.registry_untagged_retention_days
  tagged_retention_days   = var.registry_tagged_retention_days
  cleanup_dry_run         = var.registry_cleanup_dry_run
}
