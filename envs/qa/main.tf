module "stack" {
  source = "../_stack"

  project_id  = var.project_id
  region      = var.region
  zone        = var.zone
  environment = var.environment

  subnet_cidr = var.subnet_cidr
  psa_cidr    = var.psa_cidr

  create_ops_vm            = var.create_ops_vm
  create_artifact_registry = var.create_artifact_registry
  ops_machine_type         = var.ops_machine_type

  db_tier                           = var.db_tier
  db_availability_type              = var.db_availability_type
  db_deletion_protection            = var.db_deletion_protection
  db_retained_backups               = var.db_retained_backups
  db_transaction_log_retention_days = var.db_transaction_log_retention_days
  db_password_version               = var.db_password_version

  app_machine_type = var.app_machine_type
  app_min_replicas = var.app_min_replicas
  app_max_replicas = var.app_max_replicas
  app_image        = var.app_image
  app_image_digest = var.app_image_digest

  vault_deletion_protection = var.vault_deletion_protection
  vault_password_version    = var.vault_password_version

  grafana_password_version = var.grafana_password_version

  lb_allowed_members              = var.lb_allowed_members
  lb_domain                       = var.lb_domain
  iap_oauth_client_secret         = var.iap_oauth_client_secret
  iap_oauth_client_secret_version = var.iap_oauth_client_secret_version

  create_cloud_monitoring             = var.create_cloud_monitoring
  cloud_monitoring_cpu_threshold      = var.cloud_monitoring_cpu_threshold
  cloud_monitoring_notification_email = var.cloud_monitoring_notification_email
}
