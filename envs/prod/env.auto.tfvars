# Never applied. Blocked by the prod GitHub Environment and by the
# ALLOW_PROD_APPLY repository variable.

environment = "prod"

subnet_cidr = "10.12.0.0/24"
psa_cidr    = "10.22.0.0/16"

create_ops_vm            = false
create_artifact_registry = false

db_tier                           = "db-custom-2-7680"
db_availability_type              = "REGIONAL"
db_deletion_protection            = true
db_retained_backups               = 30
db_transaction_log_retention_days = 7

app_machine_type = "e2-medium"
app_min_replicas = 2
app_max_replicas = 4

vault_deletion_protection = true
