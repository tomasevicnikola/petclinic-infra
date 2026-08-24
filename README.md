# petclinic-infra

Terraform and Ansible for the Spring PetClinic capstone on Google Cloud. The
application lives in
[spring-petclinic-capstone](https://github.com/tomasevicnikola/spring-petclinic-capstone)
and ships through its own pipeline; this repo owns the infrastructure it runs
on.

Stack: GitHub Actions authenticating to GCP via Workload Identity Federation
(no service account keys), Terraform state in GCS encrypted with a
customer-managed KMS key.

## Bootstrap

One-time setup per GCP project, run by hand. It creates the state bucket, KMS
key, service accounts and federation that Terraform itself depends on and
therefore cannot create.

Prerequisites:

- `gcloud` authenticated as a principal with `roles/owner` on the project
- Project APIs already enabled: compute, sqladmin, secretmanager, cloudkms,
  iam, iamcredentials, sts, monitoring, artifactregistry, servicenetworking

```sh
./bootstrap/bootstrap.sh
```

Defaults to project `petclinic-capstone` in `europe-west3`; override with
`PROJECT_ID`, `REGION`, `GITHUB_OWNER`. Re-running is safe. On success it
prints the provider resource name and service account emails the workflows
need.

## Environments

Three environments, one GCP project, separated by name, network and Terraform
state. Each one is `envs/_stack` called once with different values.

| | `dev` | `qa` | `prod` |
| --- | --- | --- | --- |
| Status | live | applied on demand | not applied |
| State prefix | `envs/dev` | `envs/qa` | `envs/prod` |
| Subnet | `10.10.0.0/24` | `10.11.0.0/24` | `10.12.0.0/24` |
| Database | `db-g1-small`, ZONAL | `db-f1-micro`, ZONAL | `db-custom-2-7680`, REGIONAL |
| Backups kept | 7 | 1 | 30 |
| Deletion protection | on | off | on |
| Instances | 2-4 × e2-medium | 1-2 × e2-medium | 2-4 × e2-medium |
| Ops VM, image repository | creates both | uses dev's | uses dev's |
| Load balancer + IAP | own | own | own |

Every environment root is `backend.tf` plus `env.auto.tfvars`; the other five
files are identical across all three and the `fmt` job fails the build if they
diverge.

```sh
# apply; app_image_digest is needed only the first time an environment comes up
gh workflow run terraform-apply.yml -f environment=qa -f app_image_digest=sha256:...

# destroy
gh workflow run terraform-destroy.yml -f environment=qa -f confirm=qa
```

prod additionally requires the `ALLOW_PROD_APPLY` repository variable to be
`true`, and its GitHub Environment requires a reviewer.

## Who can reach the load balancer

The load balancer sits behind Identity-Aware Proxy, so reaching it means signing
in with an account that has been granted access rather than arriving from an
allowed address. That list of identities is the one value the pipeline does not
read from the code. It comes from the `LB_ALLOWED_MEMBERS` repository variable,
passed to the plan steps as `TF_VAR_lb_allowed_members`, so changing who can
reach the application is an edit in Settings followed by an apply rather than a
commit. IAP also needs an OAuth consent screen and a custom OAuth client,
configured once by hand in the console — prerequisites Terraform cannot create
for itself. The client has to be a custom one, because the Google-managed
default admits only identities internal to the organization. See
`modules/load-balancer/README.md`.

One `LB_ALLOWED_MEMBERS` value and one OAuth client serve all three
environments. Each environment still has its own backend service and therefore
its own IAP audience.

## Where the application images live

`europe-west3-docker.pkg.dev/petclinic-capstone/petclinic`, created by
`modules/artifact-registry` in the dev stack and printed by the `registry_url`
output. One repository serves every environment: the path is compiled into the
baked image's run script. The app repository's pipeline builds an image per
commit, tags it with the short SHA and pushes it there; the application VMs pull
from it. That repository is also
where `sa-cicd` gets its only permission, `roles/artifactregistry.writer`,
scoped to it alone. `sa-app-vm` still reads project-wide from bootstrap —
narrowing that is a known follow-up.

