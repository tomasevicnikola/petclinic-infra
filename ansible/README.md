# ansible

Configures every VM in the project: base packages, Docker, node exporter, the
application runner, the self-hosted GitHub runner on the ops VM, and the
monitoring stack that watches all of it. Terraform builds the machines; nothing
here creates infrastructure.

## When each role runs

Two phases. Which one a role belongs to is the thing to know before editing it.

| Role | Bake | Ops VM | Notes |
| --- | :-: | :-: | --- |
| `common` | ● | ● | Base packages, timezone, unattended-upgrades |
| `docker` | ● | ● | Engine, pinned versions, daemon config |
| `node_exporter` | ● | ● | Binds to the instance IP, resolved per boot |
| `app_runtime` | ● | | Installs the boot-time runner; never runs the app |
| `gh_runner` | | ● | Self-hosted runner registration |
| `monitoring_stack` | | ● | Prometheus, Grafana, Alertmanager |

**Bake** — `playbooks/image.yml`, run by Packer against a throwaway builder VM
whose disk becomes the `petclinic-app` image. Every application instance boots
from it, so this is how they are configured: at build time, not after boot.

**Ops VM** — `playbooks/ops.yml`. Never baked; the ops VM is a singleton.

Nothing configures a running application instance. Deploying a version does not
touch them either — it replaces them. See the application repository's
`deploy.yml`.

## Inventories

One per environment, each scoped to its own hosts by name.

| Inventory | Targets | Groups | Used by |
| --- | --- | --- | --- |
| `inventories/dev` | `petclinic-dev-*` | `ops`, `app`, `ssh_iap` | `playbooks/ops.yml` |
| `inventories/qa` | `petclinic-qa-*` | `app`, `ssh_iap` | nothing |

`ansible.cfg` defaults to `inventories/dev`. Target another with `-i`:

```sh
ansible-inventory -i inventories/qa/gcp.yml --graph
```

qa has no ops VM and its application instances configure themselves at boot, so
no playbook runs against it. The name filter matters because the `app` and `ops`
network tags are per-VPC and identical in every environment.

Only `inventories/dev` has a `group_vars/all/vault.yml`; qa has nothing to
decrypt. `scripts/fetch-vault-pass.sh` reads `<env>-ansible-vault-password` and
resolves the environment from `ANSIBLE_ENV`, defaulting to `dev`.

## Running it

Ansible only auto-discovers `ansible.cfg` in the current directory, so run from
here:

```sh
cd ansible
ansible-playbook playbooks/ops.yml
```

From the repo root, name the config instead — relative paths inside it resolve
against the file, not the working directory, so both work:

```sh
ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook ansible/playbooks/ops.yml
```

The runner needs a registration token the first time — see `docs/RUNNER.md`.

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
value, `vault_smoke_test`, and `ops.yml` asserts on it so every run states the
result rather than leaving it as an absence of an error.

**Database credentials never touch the controller.** `app_runtime` bakes a run
script that fetches them on the VM at container start, using the attached
`sa-app-vm`, and pipes them into `docker run --env-file /dev/stdin`. No env file
is written to disk, and nothing about them is in the image. Residual risk,
acknowledged in the script header: once running, root can read the environment
via `docker inspect`.

**The runner registration token is never stored.** Single-use, expires in about
an hour, passed per run; `docs/RUNNER.md` has the command.

**Grafana's password is never on disk.** `monitoring_stack` reads it from Secret
Manager at container start and hands it to Compose in the environment.

**Nothing in this tree writes a credential to disk.** Every Google API call uses
the instance's own identity from the metadata server — no service account key,
no token file.

## Roles

| Role | What it does |
| --- | --- |
| `common` | base packages, timezone, unattended security upgrades |
| `docker` | Docker Engine and compose plugin from Docker's apt repo, version pinned, log rotation and live-restore |
| `node_exporter` | pinned release, checksum verified, dedicated nologin user, hardened unit bound to the internal IP |
| `gh_runner` | ops only; replaces the manual install and adopts one that already exists |
| `app_runtime` | the boot-time runner: a systemd unit that reads the image digest from instance metadata, fetches the database credentials and starts the container |
| `monitoring_stack` | ops only; Prometheus, Grafana and Alertmanager as a digest-pinned compose project bound to loopback |

Everything downloaded is checksum-verified, the Docker apt key is checked twice
— the sha256 of the file, and the OpenPGP fingerprint of the key inside it — and
every container image is pinned by digest as well as tag. Only `ansible.builtin`
modules are used, which is what lets the CI lint job run `--offline` with no
collections installed.

### The runner is not in the docker group

`docker_group_members` is empty and stays that way. Membership is root
equivalence with extra steps, and the runner executes whatever a workflow says,
on a VM that hands out `cloud-platform` tokens. It needs no Docker access:
images are built in the application repo's pipeline and the containers run on
the app VMs.

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
no Docker and no application. 
**No readiness gate on the runner.** `gh_runner` asserts the service started,
nothing more.
