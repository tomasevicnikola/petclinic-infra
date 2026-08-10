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
