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

## Who can reach the load balancer

The load balancer sits behind Identity-Aware Proxy, so reaching it means signing
in with an account that has been granted access rather than arriving from an
allowed address. That list of identities is the one value the pipeline does not
read from the code. It comes from the `LB_ALLOWED_MEMBERS` repository variable,
passed to the plan steps as `TF_VAR_lb_allowed_members`, so changing who can
reach the application is an edit in Settings followed by an apply rather than a
commit. IAP also needs an OAuth consent screen, configured once by hand in the
console — a prerequisite Terraform cannot create for itself.

## Where the application images live

`europe-west3-docker.pkg.dev/petclinic-capstone/petclinic`, an Artifact
Registry Docker repository created by `modules/artifact-registry` and printed
by the `registry_url` output. The app repository's pipeline builds an image per
commit, tags it with the short SHA and pushes it there; the application VMs
pull from it. Cleanup policies keep the repository from growing forever — see
the module README.

That repository is also where `sa-cicd` gets its first and only permission:
`roles/artifactregistry.writer`, on this one repository. It came out of
bootstrap with no roles at all, because resource-level bindings could not be
written before the resources existed.

Known follow-up: `sa-app-vm` still holds `roles/artifactregistry.reader` at the
project level from bootstrap, which is how the VMs pull. Narrowing that to a
binding on this repository alone is the tighter shape and is deliberately not
part of this change.

