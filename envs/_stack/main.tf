locals {
  name_prefix = "petclinic-${var.environment}"

  ops_vm_service_account = "sa-ops-vm@${var.project_id}.iam.gserviceaccount.com"
  app_vm_service_account = "sa-app-vm@${var.project_id}.iam.gserviceaccount.com"
  cicd_service_account   = "sa-cicd@${var.project_id}.iam.gserviceaccount.com"

  app_image_digest = var.app_image_digest != "" ? var.app_image_digest : trimspace(
    one(data.google_storage_bucket_object_content.app_image_digest[*].content)
  )
}

data "google_storage_bucket_object_content" "app_image_digest" {
  count = var.app_image_digest == "" ? 1 : 0

  bucket = var.deploy_state_bucket
  name   = "deploy/${var.environment}/app-image-digest"
}

module "network" {
  source = "../../modules/network"

  project_id = var.project_id
  region     = var.region

  network_name = "${local.name_prefix}-vpc"
  subnet_name  = "${local.name_prefix}-subnet"
  subnet_cidr  = var.subnet_cidr
  psa_cidr     = var.psa_cidr
  app_port     = var.app_port
}

module "ops_vm" {
  source = "../../modules/ops-vm"
  count  = var.create_ops_vm ? 1 : 0

  project_id = var.project_id
  zone       = var.zone

  instance_name         = "${local.name_prefix}-ops"
  subnet_id             = module.network.subnet_id
  service_account_email = local.ops_vm_service_account

  network_tags = [module.network.tags.ssh_iap, module.network.tags.ops]
}

module "cloudsql" {
  source = "../../modules/cloudsql"

  project_id = var.project_id
  region     = var.region

  instance_name      = "${local.name_prefix}-mysql"
  network_self_link  = module.network.network_self_link
  allocated_ip_range = module.network.psa_range_name

  database_name    = var.db_name
  app_user_name    = var.db_app_user
  password_version = var.db_password_version

  tier                = var.db_tier
  availability_type   = var.db_availability_type
  deletion_protection = var.db_deletion_protection

  retained_backups               = var.db_retained_backups
  transaction_log_retention_days = var.db_transaction_log_retention_days

  secret_prefix             = "${var.environment}-db-app"
  app_service_account_email = local.app_vm_service_account

  depends_on = [module.network]
}

module "compute_mig" {
  source = "../../modules/compute-mig"

  project_id = var.project_id
  region     = var.region

  name_prefix           = "${local.name_prefix}-app"
  subnet_id             = module.network.subnet_id
  service_account_email = local.app_vm_service_account

  network_tags = [module.network.tags.ssh_iap, module.network.tags.app]
  app_port     = var.app_port

  machine_type = var.app_machine_type
  min_replicas = var.app_min_replicas
  max_replicas = var.app_max_replicas
  cpu_target   = var.app_cpu_target

  app_image        = var.app_image
  app_image_digest = local.app_image_digest
  app_env          = var.environment

  enable_autohealing = var.app_enable_autohealing
}

module "load_balancer" {
  source = "../../modules/load-balancer"

  project_id  = var.project_id
  name_prefix = "${local.name_prefix}-lb"

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

  env_prefix                = var.environment
  ops_service_account_email = local.ops_vm_service_account

  vault_password_version    = var.vault_password_version
  vault_deletion_protection = var.vault_deletion_protection

  iap_oauth_client_secret         = var.iap_oauth_client_secret
  iap_oauth_client_secret_version = var.iap_oauth_client_secret_version
}

module "artifact_registry" {
  source = "../../modules/artifact-registry"
  count  = var.create_artifact_registry ? 1 : 0

  project_id = var.project_id
  region     = var.region

  repository_id = var.registry_repository_id

  cicd_service_account_email = local.cicd_service_account

  keep_recent_count       = var.registry_keep_recent_count
  untagged_retention_days = var.registry_untagged_retention_days
  tagged_retention_days   = var.registry_tagged_retention_days
  cleanup_dry_run         = var.registry_cleanup_dry_run
}
