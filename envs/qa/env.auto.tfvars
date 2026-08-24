environment = "qa"

subnet_cidr = "10.11.0.0/24"
psa_cidr    = "10.21.0.0/16"

# Uses dev's ops VM and dev's image repository.
create_ops_vm            = false
create_artifact_registry = false

# Disposable: deletion protection off so a teardown is one destroy.
db_tier                           = "db-f1-micro"
db_availability_type              = "ZONAL"
db_deletion_protection            = false
db_retained_backups               = 1
db_transaction_log_retention_days = 1

# e2-medium, not e2-small: shared-core burst credits make cpu_utilization
# non-linear and the autoscaler reads that metric.
app_machine_type = "e2-medium"
app_min_replicas = 1
app_max_replicas = 2

vault_deletion_protection = false
