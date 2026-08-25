# secrets

Secrets that do not belong to any one component: the Ansible Vault password and
Grafana's admin password, both generated here and written to Secret Manager, and
the IAP OAuth client secret, which is supplied.

Exposes the secret id. Never the value.

Database secrets are not here — they stay in `cloudsql`, next to the instance
and the user they belong to. Nothing is created ahead of the thing that reads
it, so there is still no runner token secret.

`sa-ops-vm` reads both, because both are consumed on the ops VM. Each binding is
on that one secret, never project-wide. The vault password is deletion
protected; the Grafana password is not, since nothing is encrypted with it.

The Grafana password is created only where the ops VM exists. It is read at
container start and passed as `GF_SECURITY_ADMIN_PASSWORD`, never written to
disk. Rotate by bumping `grafana_password_version` and restarting the stack.

The value uses `ephemeral` `random_password` with the write-only
`secret_data_wo`, so it never reaches state or a plan file. Terraform keeps only
`secret_data_wo_version`, and bumping it is what rotates. That needs Terraform
1.11, google 6.23 and random 3.7, which is why this module's floor is higher
than the others.
