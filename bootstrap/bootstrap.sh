#!/usr/bin/env bash
#
# Creates what Terraform needs before it can run: state bucket, KMS key,
# service accounts, GitHub Workload Identity Federation.
#
# Safe to re-run. Everything checks before it creates.
#
# Usage: ./bootstrap/bootstrap.sh [-y]      -y skips the prompt

set -euo pipefail

# ---------------------------------------------------------------- config ----

PROJECT_ID="${PROJECT_ID:-petclinic-capstone}"
REGION="${REGION:-europe-west3}"
GITHUB_OWNER="${GITHUB_OWNER:-tomasevicnikola}"

INFRA_REPO="${INFRA_REPO:-petclinic-infra}"
APP_REPO="${APP_REPO:-spring-petclinic-capstone}"

KMS_KEYRING="tf-state"
KMS_KEY="tfstate-key"
KMS_ROTATION="90d"

BUCKET="${PROJECT_ID}-tfstate"

# Deployed-digest pointers live in their own bucket, not alongside state.
# An IAM condition cannot express "may write only under deploy/": the write path
# needs storage.objects.list, which is evaluated against the *bucket*, and a
# bucket name can never satisfy an objects/ prefix condition. See ADR 0019.
DEPLOY_BUCKET="${PROJECT_ID}-deploy"

WIF_POOL="github-pool"
WIF_PROVIDER="github-provider"

SA_TERRAFORM="sa-terraform"
SA_CICD="sa-cicd"
SA_PACKER="sa-packer"
SA_PACKER_VM="sa-packer-vm"
SA_APP_VM="sa-app-vm"
SA_OPS_VM="sa-ops-vm"

# --------------------------------------------------------------- helpers ----

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'
BLUE=$'\033[0;34m'; BOLD=$'\033[1m'; NC=$'\033[0m'

step()    { printf '\n%s==> %s%s\n' "${BOLD}${BLUE}" "$*" "${NC}"; }
created() { printf '  %s[created]%s %s\n' "${GREEN}" "${NC}" "$*"; }
exists()  { printf '  %s[exists ]%s %s\n' "${YELLOW}" "${NC}" "$*"; }
bound()   { printf '  %s[bind   ]%s %s\n' "${GREEN}" "${NC}" "$*"; }
die()     { printf '\n%serror:%s %s\n' "${RED}" "${NC}" "$*" >&2; exit 1; }

sa_email() { printf '%s@%s.iam.gserviceaccount.com' "$1" "${PROJECT_ID}"; }

ensure_sa() {
  local name="$1" display="$2" desc="$3" email
  email="$(sa_email "${name}")"
  if gcloud iam service-accounts describe "${email}" --project="${PROJECT_ID}" &>/dev/null; then
    exists "serviceAccount ${email}"
  else
    gcloud iam service-accounts create "${name}" \
      --project="${PROJECT_ID}" \
      --display-name="${display}" \
      --description="${desc}" >/dev/null
    created "serviceAccount ${email}"
  fi
}

grant_project_role() {
  local email="$1" role="$2"
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${email}" \
    --role="${role}" \
    --condition=None \
    --quiet >/dev/null
  bound "${role} -> ${email}"
}

# Both buckets get the same protections; only their contents differ.
ensure_bucket() {
  local name="$1" purpose="$2"

  if gcloud storage buckets describe "gs://${name}" --project="${PROJECT_ID}" &>/dev/null; then
    exists "bucket gs://${name} (${purpose})"
  else
    gcloud storage buckets create "gs://${name}" \
      --project="${PROJECT_ID}" \
      --location="${REGION}" \
      --uniform-bucket-level-access \
      --public-access-prevention \
      --default-encryption-key="${KMS_KEY_ID}" >/dev/null
    created "bucket gs://${name} (${purpose})"
  fi

  gcloud storage buckets update "gs://${name}" \
    --project="${PROJECT_ID}" \
    --versioning \
    --uniform-bucket-level-access \
    --public-access-prevention \
    --default-encryption-key="${KMS_KEY_ID}" >/dev/null
  printf '  %s[enforced]%s versioning, UBLA, PAP, CMEK on gs://%s\n' "${GREEN}" "${NC}" "${name}"
}

# ------------------------------------------------------------ preflight -----

command -v gcloud >/dev/null || die "gcloud not found on PATH"

step "Preflight"
ACTIVE_ACCOUNT="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null || true)"
[[ -n "${ACTIVE_ACCOUNT}" ]] || die "no active gcloud account; run: gcloud auth login"

PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)' 2>/dev/null || true)"
[[ -n "${PROJECT_NUMBER}" ]] || die "project ${PROJECT_ID} not found or not accessible as ${ACTIVE_ACCOUNT}"

printf '  account        %s\n' "${ACTIVE_ACCOUNT}"
printf '  project        %s (%s)\n' "${PROJECT_ID}" "${PROJECT_NUMBER}"
printf '  region         %s\n' "${REGION}"
printf '  github         %s/{%s,%s}\n' "${GITHUB_OWNER}" "${INFRA_REPO}" "${APP_REPO}"

if [[ "${1:-}" != "-y" ]]; then
  printf '\n%sThis creates billable cloud resources.%s Continue? [y/N] ' "${BOLD}" "${NC}"
  read -r reply
  [[ "${reply}" =~ ^[Yy]$ ]] || die "aborted"
fi

# ------------------------------------------------------- 1. KMS keyring -----

step "1. KMS keyring + key (Terraform state encryption)"

if gcloud kms keyrings describe "${KMS_KEYRING}" \
     --location="${REGION}" --project="${PROJECT_ID}" &>/dev/null; then
  exists "keyring ${KMS_KEYRING}"
else
  gcloud kms keyrings create "${KMS_KEYRING}" \
    --location="${REGION}" --project="${PROJECT_ID}" >/dev/null
  created "keyring ${KMS_KEYRING}"
fi

if gcloud kms keys describe "${KMS_KEY}" \
     --keyring="${KMS_KEYRING}" --location="${REGION}" \
     --project="${PROJECT_ID}" &>/dev/null; then
  exists "key ${KMS_KEY}"
else
  gcloud kms keys create "${KMS_KEY}" \
    --keyring="${KMS_KEYRING}" \
    --location="${REGION}" \
    --project="${PROJECT_ID}" \
    --purpose="encryption" \
    --rotation-period="${KMS_ROTATION}" \
    --next-rotation-time="+p${KMS_ROTATION}" >/dev/null
  created "key ${KMS_KEY} (rotation ${KMS_ROTATION})"
fi

KMS_KEY_ID="projects/${PROJECT_ID}/locations/${REGION}/keyRings/${KMS_KEYRING}/cryptoKeys/${KMS_KEY}"

step "1b. Grant CMEK use to the GCS service agent"

GCS_AGENT="$(gcloud storage service-agent --project="${PROJECT_ID}" 2>/dev/null \
  | grep -oE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.gserviceaccount\.com' | head -n1)"
[[ -n "${GCS_AGENT}" ]] || die "could not determine the GCS service agent for ${PROJECT_ID}"
printf '  agent          %s\n' "${GCS_AGENT}"

for attempt in 1 2 3 4 5; do
  if gcloud kms keys add-iam-policy-binding "${KMS_KEY}" \
       --keyring="${KMS_KEYRING}" \
       --location="${REGION}" \
       --project="${PROJECT_ID}" \
       --member="serviceAccount:${GCS_AGENT}" \
       --role="roles/cloudkms.cryptoKeyEncrypterDecrypter" \
       --condition=None \
       --quiet >/dev/null 2>&1; then
    bound "roles/cloudkms.cryptoKeyEncrypterDecrypter -> ${GCS_AGENT} (on key)"
    break
  fi
  [[ "${attempt}" -lt 5 ]] || die "could not grant CMEK use to ${GCS_AGENT} after 5 attempts"
  printf '  ...service agent not visible yet, retrying (%s/5)\n' "${attempt}"
  sleep 5
done

# -------------------------------------------------- 2. GCS buckets ----------

step "2. GCS buckets (Terraform state, deploy pointers)"

ensure_bucket "${BUCKET}" "Terraform state"

# Separate from state so that "may touch deploy pointers, may not touch state"
# is a bucket boundary rather than an IAM condition. Conditions cannot carry it:
# the deploy runner's write path needs storage.objects.list, which is checked
# against the bucket, and no objects/ prefix condition can ever match a bucket.
ensure_bucket "${DEPLOY_BUCKET}" "deployed-digest pointers"

# One-time carry-over for projects bootstrapped before ADR 0019. Without it an
# environment that has already deployed would have no pointer in the new bucket,
# and `terraform apply` would refuse to guess which image it runs until someone
# redeployed. Never overwrites: past the first run the deploy pipeline owns
# these objects and this script must not move them backwards.
if gcloud storage ls "gs://${BUCKET}/deploy/**" &>/dev/null; then
  while read -r src; do
    [[ -n "${src}" ]] || continue
    dst="gs://${DEPLOY_BUCKET}/${src#"gs://${BUCKET}/"}"

    if gcloud storage ls "${dst}" &>/dev/null; then
      exists "pointer ${dst}"
    else
      gcloud storage cp "${src}" "${dst}" >/dev/null
      created "pointer ${dst} (carried over from gs://${BUCKET})"
    fi
  done < <(gcloud storage ls "gs://${BUCKET}/deploy/**" 2>/dev/null)
else
  printf '  %s[none]%s no pointers to carry over from gs://%s\n' "${YELLOW}" "${NC}" "${BUCKET}"
fi

# --------------------------------------------- 3. service accounts ----------

step "3. Service accounts"

ensure_sa "${SA_TERRAFORM}" "Terraform provisioner" \
  "Provisions all infrastructure from CI via Workload Identity Federation"
ensure_sa "${SA_CICD}" "App CI/CD pipeline" \
  "Builds and pushes app images to Artifact Registry"
ensure_sa "${SA_PACKER}" "Packer image builder" \
  "Bakes the application VM image; creates a throwaway builder and publishes the image"
ensure_sa "${SA_PACKER_VM}" "Packer builder VM identity" \
  "Attached to the throwaway image builder. Holds no roles on purpose"
ensure_sa "${SA_APP_VM}" "Application VM identity" \
  "Attached to application VMs; telemetry and image pull only"
ensure_sa "${SA_OPS_VM}" "Ops/runner VM identity" \
  "Attached to the ops/runner VM; telemetry and image pull only"

TERRAFORM_SA="$(sa_email "${SA_TERRAFORM}")"
PACKER_SA="$(sa_email "${SA_PACKER}")"
PACKER_VM_SA="$(sa_email "${SA_PACKER_VM}")"
CICD_SA="$(sa_email "${SA_CICD}")"
APP_VM_SA="$(sa_email "${SA_APP_VM}")"
OPS_VM_SA="$(sa_email "${SA_OPS_VM}")"

step "3a. Roles: ${SA_TERRAFORM}"

TERRAFORM_ROLES=(
  "roles/compute.instanceAdmin.v1"          # VMs, disks, templates, MIGs
  "roles/compute.networkAdmin"              # VPC, subnets, NAT, addresses, peering
  "roles/compute.securityAdmin"             # firewall rules
  "roles/compute.loadBalancerAdmin"         # forwarding rules, backends, health checks

  "roles/cloudsql.admin"                    # SQL instance, databases, users
  "roles/secretmanager.admin"               # has to set per-secret IAM; versionManager can't
  "roles/artifactregistry.admin"            # create the repo and let sa-cicd push to it
  "roles/monitoring.editor"                 # alerts, dashboards, uptime checks
  "roles/servicenetworking.networksAdmin"   # VPC peering for Cloud SQL private IP
  "roles/iap.admin"                         # IAP settings and per-resource IAM on them
  "roles/serviceusage.serviceUsageConsumer" # bill API calls to this project
)

for role in "${TERRAFORM_ROLES[@]}"; do
  grant_project_role "${TERRAFORM_SA}" "${role}"
done

# On the bucket, not the project: state objects and nothing else in GCS.
gcloud storage buckets add-iam-policy-binding "gs://${BUCKET}" \
  --project="${PROJECT_ID}" \
  --member="serviceAccount:${TERRAFORM_SA}" \
  --role="roles/storage.objectAdmin" \
  --quiet >/dev/null
bound "roles/storage.objectAdmin -> ${TERRAFORM_SA} (on gs://${BUCKET} only)"

# Terraform only reads the pointers; the deploy pipeline is what writes them.
gcloud storage buckets add-iam-policy-binding "gs://${DEPLOY_BUCKET}" \
  --project="${PROJECT_ID}" \
  --member="serviceAccount:${TERRAFORM_SA}" \
  --role="roles/storage.objectViewer" \
  --quiet >/dev/null
bound "roles/storage.objectViewer -> ${TERRAFORM_SA} (on gs://${DEPLOY_BUCKET} only)"

# Can use the key, can't create or destroy keys.
gcloud kms keys add-iam-policy-binding "${KMS_KEY}" \
  --keyring="${KMS_KEYRING}" \
  --location="${REGION}" \
  --project="${PROJECT_ID}" \
  --member="serviceAccount:${TERRAFORM_SA}" \
  --role="roles/cloudkms.cryptoKeyEncrypterDecrypter" \
  --condition=None \
  --quiet >/dev/null
bound "roles/cloudkms.cryptoKeyEncrypterDecrypter -> ${TERRAFORM_SA} (on key only)"

for target in "${APP_VM_SA}" "${OPS_VM_SA}"; do
  gcloud iam service-accounts add-iam-policy-binding "${target}" \
    --project="${PROJECT_ID}" \
    --member="serviceAccount:${TERRAFORM_SA}" \
    --role="roles/iam.serviceAccountUser" \
    --quiet >/dev/null
  bound "roles/iam.serviceAccountUser -> ${TERRAFORM_SA} (on ${target} only)"
done

step "3b. Roles: ${SA_CICD}"

printf '  %s[none]%s no project-level roles yet, bindings go on the resources\n' \
  "${YELLOW}" "${NC}"

VM_ROLES=(
  "roles/logging.logWriter"                   # Ops Agent logs
  "roles/monitoring.metricWriter"             # Ops Agent metrics
  "roles/stackdriver.resourceMetadata.writer" # Ops Agent labels its own VM; 403 loop without it
  "roles/artifactregistry.reader"             # docker pull
)

step "3c. Roles: ${SA_APP_VM}"
for role in "${VM_ROLES[@]}"; do grant_project_role "${APP_VM_SA}" "${role}"; done

OPS_CONTROLLER_ROLES=(
  "roles/compute.viewer"             # gcp_compute dynamic inventory lists the MIG instances
  "roles/iap.tunnelResourceAccessor" # open the IAP SSH tunnel; no VM has a public IP
  "roles/compute.osAdminLogin"       # SSH with sudo onto an app instance, for debugging
)

step "3d. Roles: ${SA_OPS_VM}"
for role in "${VM_ROLES[@]}"; do grant_project_role "${OPS_VM_SA}" "${role}"; done
for role in "${OPS_CONTROLLER_ROLES[@]}"; do grant_project_role "${OPS_VM_SA}" "${role}"; done

gcloud iam service-accounts add-iam-policy-binding "${APP_VM_SA}" \
  --project="${PROJECT_ID}" \
  --member="serviceAccount:${OPS_VM_SA}" \
  --role="roles/iam.serviceAccountUser" \
  --quiet >/dev/null
bound "roles/iam.serviceAccountUser -> ${OPS_VM_SA} (on ${APP_VM_SA} only)"

# Unconditioned, on the pointer bucket only. A condition here would be worse
# than useless: roles/storage.objectUser includes storage.objects.list, but a
# list is authorised against the bucket, whose resource.name can never start
# with .../objects/deploy/. That made every *first* write to an environment
# impossible while overwrites kept working, so only dev - hand-seeded - ever
# succeeded. The boundary is the bucket now. See ADR 0019.
gcloud storage buckets add-iam-policy-binding "gs://${DEPLOY_BUCKET}" \
  --project="${PROJECT_ID}" \
  --member="serviceAccount:${OPS_VM_SA}" \
  --role="roles/storage.objectUser" \
  --condition=None \
  --quiet >/dev/null
bound "roles/storage.objectUser -> ${OPS_VM_SA} (on gs://${DEPLOY_BUCKET}, unconditioned)"

# Converge projects bootstrapped before ADR 0019: drop every objectUser binding
# for the ops runner on the state bucket, conditioned or not. --all rather than
# a literal --condition, because the live binding may carry a description this
# script never set. Absent binding is not an error worth stopping for.
if gcloud storage buckets remove-iam-policy-binding "gs://${BUCKET}" \
     --project="${PROJECT_ID}" \
     --member="serviceAccount:${OPS_VM_SA}" \
     --role="roles/storage.objectUser" \
     --all \
     --quiet >/dev/null 2>&1; then
  bound "removed roles/storage.objectUser <- ${OPS_VM_SA} (on gs://${BUCKET})"
else
  exists "no roles/storage.objectUser for ${OPS_VM_SA} on gs://${BUCKET}"
fi

step "3e. Roles: ${SA_PACKER}"

# Short on purpose: the bake creates a throwaway VM and publishes an image.
# Running it as sa-terraform would hand it secretmanager.admin and cloudsql.admin
# for no reason.
PACKER_ROLES=(
  "roles/compute.instanceAdmin.v1"          # builder VM and disk, and publishing the image
  "roles/serviceusage.serviceUsageConsumer" # bill API calls to this project
)

for role in "${PACKER_ROLES[@]}"; do
  grant_project_role "${PACKER_SA}" "${role}"
done

# The builder VM's identity holds no roles. Not sa-app-vm: that account can read
# the live database secrets.
gcloud iam service-accounts add-iam-policy-binding "${PACKER_VM_SA}" \
  --project="${PROJECT_ID}" \
  --member="serviceAccount:${PACKER_SA}" \
  --role="roles/iam.serviceAccountUser" \
  --quiet >/dev/null
bound "roles/iam.serviceAccountUser -> ${PACKER_SA} (on ${PACKER_VM_SA} only)"

# ------------------------------------- 4. Workload Identity Federation -------

step "4. Workload Identity Federation (GitHub OIDC)"

if gcloud iam workload-identity-pools describe "${WIF_POOL}" \
     --location="global" --project="${PROJECT_ID}" &>/dev/null; then
  exists "pool ${WIF_POOL}"
else
  gcloud iam workload-identity-pools create "${WIF_POOL}" \
    --location="global" \
    --project="${PROJECT_ID}" \
    --display-name="GitHub Actions" \
    --description="OIDC federation for GitHub Actions; replaces SA JSON keys" >/dev/null
  created "pool ${WIF_POOL}"
fi

ATTR_CONDITION="assertion.repository_owner == '${GITHUB_OWNER}' && assertion.repository in ['${GITHUB_OWNER}/${INFRA_REPO}', '${GITHUB_OWNER}/${APP_REPO}']"

ATTR_MAPPING="google.subject=assertion.sub"
ATTR_MAPPING+=",attribute.repository=assertion.repository"
ATTR_MAPPING+=",attribute.repository_owner=assertion.repository_owner"
ATTR_MAPPING+=",attribute.ref=assertion.ref"

if gcloud iam workload-identity-pools providers describe "${WIF_PROVIDER}" \
     --workload-identity-pool="${WIF_POOL}" \
     --location="global" --project="${PROJECT_ID}" &>/dev/null; then
  exists "provider ${WIF_PROVIDER}"
  gcloud iam workload-identity-pools providers update-oidc "${WIF_PROVIDER}" \
    --workload-identity-pool="${WIF_POOL}" \
    --location="global" \
    --project="${PROJECT_ID}" \
    --attribute-mapping="${ATTR_MAPPING}" \
    --attribute-condition="${ATTR_CONDITION}" >/dev/null
  printf '  %s[enforced]%s attribute mapping + condition\n' "${GREEN}" "${NC}"
else
  gcloud iam workload-identity-pools providers create-oidc "${WIF_PROVIDER}" \
    --workload-identity-pool="${WIF_POOL}" \
    --location="global" \
    --project="${PROJECT_ID}" \
    --display-name="GitHub OIDC" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="${ATTR_MAPPING}" \
    --attribute-condition="${ATTR_CONDITION}" >/dev/null
  created "provider ${WIF_PROVIDER}"
fi

WIF_POOL_ID="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WIF_POOL}"
WIF_PROVIDER_ID="${WIF_POOL_ID}/providers/${WIF_PROVIDER}"

step "4b. Repo -> service account bindings"

bind_repo_to_sa() {
  local repo="$1" target_sa="$2"
  gcloud iam service-accounts add-iam-policy-binding "${target_sa}" \
    --project="${PROJECT_ID}" \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/${WIF_POOL_ID}/attribute.repository/${GITHUB_OWNER}/${repo}" \
    --quiet >/dev/null
  bound "${GITHUB_OWNER}/${repo} -> ${target_sa}"
}

bind_repo_to_sa "${INFRA_REPO}" "${TERRAFORM_SA}"
bind_repo_to_sa "${INFRA_REPO}" "${PACKER_SA}"
bind_repo_to_sa "${APP_REPO}"   "${CICD_SA}"

# ----------------------------------------------------------- 5. output ------

cat <<EOF

${BOLD}================================================================${NC}
${BOLD} GitHub Actions configuration values${NC}
${BOLD}================================================================${NC}

  workload_identity_provider:
    ${WIF_PROVIDER_ID}

  service_account (${INFRA_REPO}):
    ${TERRAFORM_SA}

  service_account (${APP_REPO}):
    ${CICD_SA}

  Terraform backend:
    bucket = "${BUCKET}"
    prefix = "envs/dev"

  Deploy pointer bucket (deploy_state_bucket / DEPLOY_BUCKET):
    ${DEPLOY_BUCKET}

Example step (needs: permissions: id-token: write, contents: read)

  - uses: google-github-actions/auth@v2
    with:
      workload_identity_provider: ${WIF_PROVIDER_ID}
      service_account: ${TERRAFORM_SA}

EOF
