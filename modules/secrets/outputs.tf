output "ansible_vault_secret_id" {
  description = "Secret holding the Ansible Vault password, read by scripts/fetch-vault-pass.sh."
  value       = google_secret_manager_secret.ansible_vault.secret_id
}

output "iap_oauth_client_secret_id" {
  description = "Secret holding the IAP OAuth client secret. Durable copy for rotation; nothing reads it at run time."
  value       = google_secret_manager_secret.iap_oauth_client.secret_id
}
