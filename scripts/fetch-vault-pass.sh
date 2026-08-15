#!/usr/bin/env bash
# Prints the Ansible Vault password on stdout and nothing else, so it can be
# used as an executable vault_password_file. ansible.cfg points at it once
# Ansible arrives; nothing writes the password to disk.
set -euo pipefail

PROJECT_ID="${VAULT_SECRET_PROJECT:-petclinic-capstone}"
SECRET_ID="${VAULT_SECRET_ID:-dev-ansible-vault-password}"

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud not found on PATH" >&2
  exit 1
fi

gcloud secrets versions access latest \
  --secret="${SECRET_ID}" \
  --project="${PROJECT_ID}"
