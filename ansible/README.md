# ansible

Configures every VM in the dev project: base packages, Docker, node exporter,
the self-hosted GitHub runner on the ops VM, and the application container on
the MIG instances. Terraform builds the machines; nothing here creates
infrastructure.

## Running it

Ansible only auto-discovers `ansible.cfg` in the current directory, so run from
here:

```sh
cd ansible
ansible-playbook playbooks/app.yml
```

From the repo root, name the config instead — relative paths inside it resolve
against the file, not the working directory, so both work:

```sh
ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook ansible/playbooks/app.yml
```

`site.yml` runs both plays, ops first. `app.yml` is `serial: 1`, so a bad change
takes one instance out of the load balancer at a time instead of all of them.
The runner needs a registration token the first time — see `docs/RUNNER.md`.

### Deploying a version

Roles are tagged, so a deploy selects a subset:

```sh
ansible-playbook playbooks/app.yml \
  --tags common,docker,app_deploy \
  -e app_deploy_image=europe-west3-docker.pkg.dev/petclinic-capstone/petclinic/petclinic-app@sha256:... \
  -e app_deploy_placeholder=false
```

That is what `deploy.yml` in the application repository runs, with a digest
rather than a tag. `common` and `docker` are in because a fresh MIG instance has
no Docker and `serial: 1` makes one failed host end the play.

`app_deploy_placeholder` defaults to `true`, so a bare `app.yml` run puts the
placeholder back.

### Prerequisites

```sh
ansible-galaxy collection install -r requirements.yml
pip install "google-auth>=2.0" "requests>=2.31"
gcloud auth application-default login
```

The pip packages are what the `gcp_compute` inventory plugin imports. Without
them it does not fail loudly — it returns an empty inventory and every play
matches no hosts. `unparsed_is_failed` in `ansible.cfg` turns that into an error.

You also need an OS Login SSH key. The first `gcloud compute ssh` to any
instance creates and registers one at `~/.ssh/google_compute_engine`.

**Also runs on the ops VM.** `sa-ops-vm` has `compute.viewer`,
`iap.tunnelResourceAccessor`, `compute.osAdminLogin` and `iam.serviceAccountUser`
on `sa-app-vm`, all from `bootstrap.sh`. `ansible-core` and the inventory
plugin's imports come from `common_extra_packages` in `group_vars/ops.yml`.

## Connection model

No VM has a public IP, so every SSH session goes through an IAP tunnel:
`ansible_ssh_common_args` wraps `gcloud compute start-iap-tunnel` in a
ProxyCommand, which leaves Ansible in control of the SSH invocation.

The tunnel addresses instances by name, which is why `inventory_hostname` and
not `%h` is passed to it — `%h` would be whatever `ansible_host` resolves to.

`ansible_connection` picks `local` when the controller *is* the target. On the
ops VM the ops play then configures the machine it runs on with no tunnel back
into itself; from a laptop the hostname never matches an instance name, so
everything goes over SSH.

Host key checking is trust-on-first-use, `StrictHostKeyChecking=accept-new`: MIG
instances come back under the same name with a fresh key, so a pre-seeded
`known_hosts` would be stale more often than not, while a changed key on a host
already seen still fails hard.

When it breaks, it breaks on the first task:

| Symptom | Cause |
| --- | --- |
| Permission denied on the tunnel | missing `iap.tunnelResourceAccessor` or `compute.osLogin` |
| Publickey rejected | no registered OS Login key — run `gcloud compute ssh` once |
| Empty inventory | stale ADC, or the pip packages above are missing |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | MIG replaced an instance under the same name; `ssh-keygen -R <name>` |

## Secrets

Secret Manager is primary; see `docs/secrets.md`. Nothing sensitive is stored in
this tree.

**Vault.** `inventories/dev/group_vars/all/vault.yml` is committed encrypted.
The password is not in the repo and never on disk: `ansible.cfg` points
`vault_password_file` at `scripts/fetch-vault-pass.sh`, which reads
`dev-ansible-vault-password` out of Secret Manager and prints it. "Can decrypt
this file" is therefore an IAM binding that can be revoked. The file holds one
placeholder, `vault_smoke_test`, and both playbooks assert on it so every run
states the result rather than leaving it as an absence of an error.

**Database credentials never touch the controller.** `app_deploy` renders a run
script that fetches them on the VM at container start, using the attached
`sa-app-vm`, and pipes them into `docker run --env-file /dev/stdin`. No env file
is written to disk. The config half — host, port, database, user — is read on
every start because none of it is a credential; the password is read only for an
image that can use one. Residual risk, acknowledged in the script header: once
running, root can read the environment via `docker inspect`.

**The runner registration token is never stored.** Single-use, expires in about
an hour, passed per run; `docs/RUNNER.md` has the command.

## Roles

| Role | What it does |
| --- | --- |
| `common` | base packages, timezone, unattended security upgrades |
| `docker` | Docker Engine and compose plugin from Docker's apt repo, version pinned, log rotation and live-restore |
| `node_exporter` | pinned release, checksum verified, dedicated nologin user, hardened unit bound to the internal IP |
| `gh_runner` | ops only; replaces the manual install and adopts one that already exists |
| `app_deploy` | the application container under systemd: removes the previous version, pulls the image, runs it, verifies health and datasource |

Everything downloaded is checksum-verified, and the Docker apt key is checked
twice — the sha256 of the file, and the OpenPGP fingerprint of the key inside
it. Only `ansible.builtin` modules are used, which is what lets the CI lint job
run `--offline` with no collections installed.

### The runner is not in the docker group

`docker_group_members` is empty and stays that way. Membership is root
equivalence with extra steps, and the runner executes whatever a workflow says,
on a VM that hands out `cloud-platform` tokens. It needs no Docker access:
images are built in the application repo's pipeline and the containers run on
the app VMs.

### The placeholder answers /actuator/health on purpose

The load balancer health check requests `/actuator/health`, which Spring Boot
Actuator serves once the real application runs. That check is not touched here;
repointing it at `/` would mean the thing verified today is not the thing
verified in production.

So the placeholder was made to fit the probe instead: an unprivileged nginx,
pinned by digest, serving a file at `actuator/health`. The backend goes HEALTHY
on the same probe the real application will answer, which exercises the load
balancer, the named port, the health-check firewall rule and the MIG end to end.
Auto-healing stays off in Terraform until the real image lands — a placeholder
passing the probe is exactly what you do not want the group treating as success.

## Linting

```sh
ANSIBLE_INVENTORY=/dev/null ansible-lint --offline
```

`/dev/null`, not `'localhost,'`. `ANSIBLE_INVENTORY` is a comma-separated list
of inventory *sources*, not a host pattern: `'localhost,'` splits into
`['localhost', '']`, the empty element resolves to the working directory,
Ansible parses `ansible/` as a directory inventory, finds
`inventories/dev/gcp.yml` and calls the live GCE API.

CI runs the same command on a GitHub-hosted runner. There is still no
`ansible-playbook` job here: reaching these VMs needs the self-hosted runner,
and no `runs-on: self-hosted` job may have a `pull_request` trigger while the
repos are public. The playbook runs from `deploy.yml` in the application
repository instead, on `workflow_dispatch` only.

## Idempotency

Second run, four MIG instances, two of which the autoscaler created mid-run:

```
petclinic-dev-app-8nmg : ok=33 changed=0 unreachable=0 failed=0 skipped=3
petclinic-dev-app-95h0 : ok=33 changed=0 unreachable=0 failed=0 skipped=3
petclinic-dev-app-brrz : ok=38 changed=28 unreachable=0 failed=0 skipped=2
petclinic-dev-app-hklx : ok=38 changed=28 unreachable=0 failed=0 skipped=2
```

The `changed=0` lines are the proof; the `changed=28` lines are the gap below.

## Known gaps

**Autoscaling produces unconfigured instances.** The instance template installs
no Docker and no application. Autohealing recreates them and a deploy repairs
them, since it runs the baseline roles too. The real fix — a baked image — is
not built.

**A bare baseline run reverts the app to the placeholder.** `app.yml` without
`app_deploy_image` and `app_deploy_placeholder=false` re-templates the run
script back to nginx. Always deploy through the pipeline.

**No readiness gate on the runner.** `app_deploy` waits for the health check;
`gh_runner` only asserts the service started.
