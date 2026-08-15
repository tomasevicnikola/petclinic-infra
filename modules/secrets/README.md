# secrets

Secrets that do not belong to any one component. Right now that is the Ansible
Vault password, generated here and written to Secret Manager.

Exposes the secret id. Never the value.

Database secrets are not here — they stay in `cloudsql`, next to the instance
and the user they belong to. Nothing is created ahead of the thing that reads
it, so there is no runner token secret and no Grafana password yet.

`sa-ops-vm` reads the vault password, because that is where Ansible runs. The
binding is on that one secret, never project-wide. The secret is deletion
protected and old versions are disabled rather than destroyed, since it is the
only copy and the files it opens live in git.

The value uses `ephemeral` `random_password` with the write-only
`secret_data_wo`, so it never reaches state or a plan file. Terraform keeps only
`secret_data_wo_version`, and bumping it is what rotates. That needs Terraform
1.11, google 6.23 and random 3.7, which is why this module's floor is higher
than the others.
