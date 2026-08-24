#!/usr/bin/env bash
# Prints the Ansible Vault password on stdout, for use as an executable
# vault_password_file. Reads <environment>-ansible-vault-password.
#
# Environment resolution: VAULT_SECRET_ID, then $1, then ANSIBLE_ENV, then dev.
# Ansible calls this with no arguments, so ANSIBLE_ENV is the one it can use.
set -euo pipefail

ENVIRONMENT="${1:-${ANSIBLE_ENV:-dev}}"

if [[ ! "${ENVIRONMENT}" =~ ^[a-z][a-z0-9-]{0,15}$ ]]; then
  echo "'${ENVIRONMENT}' is not an environment name" >&2
  exit 1
fi

PROJECT_ID="${VAULT_SECRET_PROJECT:-petclinic-capstone}"
SECRET_ID="${VAULT_SECRET_ID:-${ENVIRONMENT}-ansible-vault-password}"

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud not found on PATH" >&2
  exit 1
fi

gcloud secrets versions access latest \
  --secret="${SECRET_ID}" \
  --project="${PROJECT_ID}"
