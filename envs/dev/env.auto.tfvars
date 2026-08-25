environment = "dev"

subnet_cidr = "10.10.0.0/24"
psa_cidr    = "10.20.0.0/16"

create_ops_vm            = true
create_artifact_registry = true
ops_machine_type         = "e2-medium"

db_tier                           = "db-g1-small"
db_availability_type              = "ZONAL"
db_deletion_protection            = true
db_retained_backups               = 7
db_transaction_log_retention_days = 7

app_machine_type = "e2-medium"
app_min_replicas = 2
app_max_replicas = 4

vault_deletion_protection = true
