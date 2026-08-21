# Runners on the ops VM

Managed by Ansible. `ansible/roles/gh_runner` owns the user, the directory, the
pinned runner release and its systemd service; there is nothing left to do by
hand except hand it a registration token the first time.

**While the repos are public, no `runs-on: self-hosted` job may have a
`pull_request` trigger.** A fork PR would run its own code on a VM in the VPC
that hands out `cloud-platform` tokens. Dispatch and pushes to `main` only. This
is unchanged and it is the constraint that decides what may be moved here at
all — the Ansible lint job in `terraform-ci.yml` runs on `ubuntu-latest` for
exactly this reason.

The application repository's `deploy.yml` is the one job that runs here, and it
is `workflow_dispatch`-only so the rule above holds without exception.

## Two registrations, one host

| Repository | Directory |
| --- | --- |
| `petclinic-infra` | `/opt/actions-runner` |
| `spring-petclinic-capstone` | `/opt/actions-runner-app` |

A runner is scoped to one repository and there is no organisation to share one
across, so the role runs twice from `playbooks/ops.yml` with
`allow_duplicates: true`. The systemd unit name comes from the repository, and
both carry `self-hosted,gcp,ops` — a job is only offered to runners registered
to the repository it came from.

## Run it

From `ansible/` — Ansible only auto-discovers `ansible.cfg` in the current
directory, so running from the repo root reads no config at all. If you want to
stay at the root, name it explicitly instead:
`ANSIBLE_CONFIG=ansible/ansible.cfg`; paths inside the file resolve against the
file, so that works too.

```sh
cd ansible
read -rsp 'Infra registration token: ' T_INFRA; echo
read -rsp 'App registration token: '   T_APP;   echo
ansible-playbook playbooks/ops.yml \
  -e gh_runner_infra_token="$T_INFRA" \
  -e gh_runner_app_token="$T_APP"
unset T_INFRA T_APP
```

Neither is called `gh_runner_token`: `-e` outranks a role parameter and would
hand one repository's token to both.

Either token can be omitted if that runner is already registered. Adding the
second runner to a host that already has the first:

```sh
read -rsp 'App registration token: ' T_APP; echo
ansible-playbook playbooks/ops.yml --tags gh_runner -e gh_runner_app_token="$T_APP"
unset T_APP
```

`read -rsp` rather than pasting the token onto the command line: an inline value
lands in `.bash_history` and is visible in `ps` for the length of the run. Same
reason the removal command at the bottom of this page uses it.

Needs Application Default Credentials for the dynamic inventory
(`gcloud auth application-default login`) and an OS Login SSH key, which the
first `gcloud compute ssh` to any instance creates and registers.

The token is only needed when that runner is not registered yet. Once `.runner`
exists in the instance's directory, the role skips registration entirely and the
same command works with no extra vars:

```sh
ansible-playbook playbooks/ops.yml
```

That is also how a runner installed by hand is adopted rather than rebuilt: the
role looks for `/opt/actions-runner/.runner`, and an existing install — however
it got there — satisfies it.

The flip side, and it is deliberate: on a host that already has a runner the
role reconciles nothing. Changing the labels, the URL, the name **or the pinned
version** in the role has no effect there, because the download and the
`config.sh` call both sit inside the block that such a host skips. Converging
the version would mean stopping the service and unpacking a release over a live
installation on the one host the pipeline depends on; converging the labels
would need a long-lived GitHub PAT on the ops VM. Neither is worth it for
settings that change about once a year. To change any of them, remove the runner
(bottom of this page) and register it again.

## Token

GitHub → Settings → Actions → Runners → New self-hosted runner, and copy the
token from the `config.sh` line. Or:

```sh
gh api -X POST repos/tomasevicnikola/petclinic-infra/actions/runners/registration-token \
  --jq .token

gh api -X POST repos/tomasevicnikola/spring-petclinic-capstone/actions/runners/registration-token \
  --jq .token
```

One per repository; a token minted for one will not register against the other.

It lasts about an hour and is single-use, which is why it is passed per run and
is not in Ansible Vault and not in Secret Manager. Storing a credential that
expires before anything could read it buys nothing and leaves a long-lived
secret standing in for a short-lived one. The task that consumes it is
`no_log`; it is still an argument to `config.sh`, so it appears in `ps` on the
ops VM for a second or two, on a host only reachable through IAP, by which time
the token is already spent.

## What it sets up

- User `runner`, no sudo, and **not** in the `docker` group. Jobs are arbitrary
  repo code; the docker group is root with extra steps. Reasoning in
  `ansible/README.md`, "The runner is not in the docker group".
- One directory per registration, mode 0750 — `config.sh` leaves long-lived
  credentials in `.credentials` there.
- Runner version and SHA-256 pinned in the role defaults, checksum verified on
  download, taken from the release notes rather than from the downloaded file.
- `--disableupdate`, so the pinned version keeps describing what is installed
  instead of the runner replacing its own binary overnight.
- `--replace`, so a rebuilt ops VM can take its name back instead of failing
  against the offline runner the old VM left behind.
- Labels `self-hosted,gcp,ops` on both, unchanged from the manual install.
- Service via the vendor's `svc.sh`, so the unit name matches what a hand
  install produces and both are managed the same way.

Not `--ephemeral`. It needs something to register the replacement after each
job — a long-lived PAT or a GitHub App on this VM — which is close to circular.
Instead: the runner user has no sudo and no Docker access, and the only workflow
that reaches this host is `workflow_dispatch`-gated behind a required reviewer.

## SSH in

For looking around; not needed to run the playbook.

```sh
gcloud compute ssh petclinic-dev-ops \
  --project=petclinic-capstone --zone=europe-west3-a --tunnel-through-iap
```

No external IP, so it only works through the tunnel. A non-owner also needs
`roles/iap.tunnelResourceAccessor` and `roles/compute.osAdminLogin`.

## When the VM is replaced

Destroying the VM takes the runner with it and leaves an offline entry in
GitHub. Re-running `playbooks/ops.yml` with a fresh token puts it back and
`--replace` reclaims the name, so there is no manual delete step any more.

Deletion protection stays off on purpose, so the destroy workflow keeps working.

## Remove

Per instance — `/opt/actions-runner` for infra, `/opt/actions-runner-app` for
the application repository — and the removal token must come from that same
repository:

```sh
cd /opt/actions-runner-app          # or /opt/actions-runner
sudo ./svc.sh stop && sudo ./svc.sh uninstall
read -rsp 'Removal token: ' RUNNER_TOKEN; echo
sudo -u runner ./config.sh remove --token "$RUNNER_TOKEN"
unset RUNNER_TOKEN
```

`read -rsp` so the token does not land in `.bash_history` or show up in `ps`.
