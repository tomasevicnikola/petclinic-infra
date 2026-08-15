output "ansible_vault_secret_id" {
  description = "Secret holding the Ansible Vault password, read by scripts/fetch-vault-pass.sh."
  value       = google_secret_manager_secret.ansible_vault.secret_id
}
