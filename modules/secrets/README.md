# secrets

The cross-cutting secrets: the Grafana admin password and the Ansible Vault
password. Both are generated here and written to Secret Manager.

Exposes the two secret ids. Never the values.

The database secrets are not here. They stay in the `cloudsql` module with the
instance and the user they belong to — a secret whose value comes from a
resource next to it is easier to reason about than one wired in from a
different module, and moving them would be a state move for nothing.

There is no runner token secret. Registration tokens last about an hour and are
spent on the first use, so a stored one is expired before anything can read it.

`sa-ops-vm` gets `secretAccessor` on the vault password, because that is where
Ansible runs. Nothing is granted on the Grafana password yet; that binding
arrives with the monitoring stack. Bindings are per secret, so no consumer can
list or read anything else in the project.

## Values out of state

Both passwords use `ephemeral` `random_password` and the write-only
`secret_data_wo` argument, so neither value is ever written to state or to a
plan file. An ephemeral resource is opened when the graph reaches it and closed
at the end of the run; a write-only argument is passed to the provider on apply
and dropped. Terraform therefore cannot diff the value, and
`secret_data_wo_version` — a plain stored number — is what tells the provider
to write a new version. A new password is generated on every run and thrown
away; only a bump of `grafana_password_version` or `vault_password_version`
rotates anything.

This needs Terraform >= 1.11, google >= 6.14 and random >= 3.7, which is why
this module asks for a higher version floor than the others.
