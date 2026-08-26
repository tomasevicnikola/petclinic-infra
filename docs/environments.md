# Environments

Three environments in one GCP project, separated by name, network and Terraform
state. Each is `envs/_stack` called once with different values.

| | `dev` | `qa` | `prod` |
| --- | --- | --- | --- |
| Status | live | applied on demand | not applied |
| State prefix | `envs/dev` | `envs/qa` | `envs/prod` |
| VPC / subnet | `10.10.0.0/24` | `10.11.0.0/24` | `10.12.0.0/24` |
| PSA range | `10.20.0.0/16` | `10.21.0.0/16` | `10.22.0.0/16` |
| Database | `db-g1-small`, ZONAL | `db-f1-micro`, ZONAL | `db-custom-2-7680`, REGIONAL |
| Backups kept | 7 | 1 | 30 |
| Deletion protection | on | off | on |
| Instances | 2-4 × e2-medium | 1-2 × e2-medium | 2-4 × e2-medium |
| Ops VM | yes | no | no |
| Image repository | yes | no | no |
| Load balancer + IAP | own | own | own |
| Secrets | `dev-*` | `qa-*` | `prod-*` |

## Layout

```
envs/_stack/      every module, called once
envs/<env>/       backend.tf + env.auto.tfvars + five files identical across all three
```

`versions.tf`, `providers.tf`, `variables.tf`, `main.tf` and `outputs.tf` are
byte-identical in `dev`, `qa` and `prod`. The `fmt` job in `terraform-ci.yml`
diffs them and also asserts the set of `.tf` files in each directory.

## Shared between environments

- **Ops VM** — one controller and one pair of runners, created by dev.
- **Image repository** — `.../petclinic/petclinic-app`. The path is compiled
  into the baked image's run script, so it is the same for every environment.
- **Image family** — `petclinic-app`. One bake serves all three; `app-env`
  instance metadata is what makes an instance belong to an environment.
- **IAP OAuth client** — one client and one consent screen. Each environment has
  its own backend service and therefore its own IAP audience.
- **`LB_ALLOWED_MEMBERS`** — one repository variable for all three.

## Running an environment

```sh
# Standing an environment up: deploy to it. The deploy records the digest at
# deploy/<env>/app-image-digest and dispatches the apply itself, so a brand-new
# environment needs nothing placed by hand first.
gh workflow run deploy.yml -f version=v1.5.0 -f environment=qa   # app repository

# Applying directly - a firewall change, a monitoring tweak. An environment that
# has already deployed needs no digest: Terraform reads its pointer. One that
# never has must say which image it wants, because the apply will not guess and
# will not inherit another environment's build.
gh workflow run terraform-apply.yml -f environment=qa
gh workflow run terraform-apply.yml -f environment=qa -f app_image_digest=sha256:...

# destroy
gh workflow run terraform-destroy.yml -f environment=qa -f confirm=qa
```

qa's application instances configure themselves from the baked image at boot;
no Ansible run is involved.

## prod

`envs/prod` is planned and reviewed on every pull request that touches shared
code, and has never been applied. Three things block it:

- the `prod` GitHub Environment, in both repositories, requires a reviewer and
  only allows `main`. `dev` and `qa` require neither
- `terraform-apply.yml` and `terraform-destroy.yml` fail unless the
  `ALLOW_PROD_APPLY` repository variable is exactly `true`
- `deploy.yml` in the application repository fails unless `ALLOW_PROD_DEPLOY`
  is exactly `true` — its own variable, since repository variables do not cross
  repositories

Applying it would cost roughly €390 a month, dominated by the REGIONAL database.

## Reachability

The ops VM is in dev's VPC and the environments are not peered.

| Path | Cross-environment |
| --- | :-: |
| SSH / Ansible over IAP | yes |
| `gcloud`, Secret Manager, MIG status | yes |
| Direct connection to an instance's internal IP | no |

The deploy pipeline uses the load balancer's per-instance health state for any
environment other than dev.
