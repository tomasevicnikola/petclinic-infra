output "grafana_admin_secret_id" {
  description = "Secret holding the Grafana admin password. The id, not the payload."
  value       = google_secret_manager_secret.grafana_admin.secret_id
}

output "ansible_vault_secret_id" {
  description = "Secret holding the Ansible Vault password, read by scripts/fetch-vault-pass.sh."
  value       = google_secret_manager_secret.ansible_vault.secret_id
}
