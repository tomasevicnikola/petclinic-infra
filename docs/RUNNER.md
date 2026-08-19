# Runner on the ops VM

Managed by Ansible. `ansible/roles/gh_runner` owns the user, the directory, the
pinned runner release and its systemd service; there is nothing left to do by
hand except hand it a registration token the first time.

**While the repos are public, no `runs-on: self-hosted` job may have a
`pull_request` trigger.** A fork PR would run its own code on a VM in the VPC
that hands out `cloud-platform` tokens. Dispatch and pushes to `main` only. This
is unchanged and it is the constraint that decides what may be moved here at
all — the Ansible lint job in `terraform-ci.yml` runs on `ubuntu-latest` for
exactly this reason.

## Run it

From `ansible/` — Ansible only auto-discovers `ansible.cfg` in the current
directory, so running from the repo root reads no config at all. If you want to
stay at the root, name it explicitly instead:
`ANSIBLE_CONFIG=ansible/ansible.cfg`; paths inside the file resolve against the
file, so that works too.

```sh
cd ansible
read -rsp 'Registration token: ' T; echo
ansible-playbook playbooks/ops.yml -e gh_runner_token="$T"; unset T
```

`read -rsp` rather than pasting the token onto the command line: an inline value
lands in `.bash_history` and is visible in `ps` for the length of the run. Same
reason the removal command at the bottom of this page uses it.

Needs Application Default Credentials for the dynamic inventory
(`gcloud auth application-default login`) and an OS Login SSH key, which the
first `gcloud compute ssh` to any instance creates and registers.

The token is only needed when no runner is registered yet. Once `.runner` exists
in `/opt/actions-runner`, the role skips registration entirely and the same
command works with no extra vars:

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
```

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
- `/opt/actions-runner`, mode 0750 — `config.sh` leaves long-lived credentials
  in `.credentials` there.
- Runner version and SHA-256 pinned in the role defaults, checksum verified on
  download, taken from the release notes rather than from the downloaded file.
- `--disableupdate`, so the pinned version keeps describing what is installed
  instead of the runner replacing its own binary overnight.
- `--replace`, so a rebuilt ops VM can take its name back instead of failing
  against the offline runner the old VM left behind.
- Labels `self-hosted,gcp,ops`, unchanged from the manual install.
- Service via the vendor's `svc.sh`, so the unit name matches what a hand
  install produces and both are managed the same way.

Not `--ephemeral` yet. It is the right answer once jobs actually run here, but
it needs something to register the replacement after each job, and that
automation arrives with the deploy phase.

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

```sh
cd /opt/actions-runner
sudo ./svc.sh stop && sudo ./svc.sh uninstall
read -rsp 'Removal token: ' RUNNER_TOKEN; echo
sudo -u runner ./config.sh remove --token "$RUNNER_TOKEN"
unset RUNNER_TOKEN
```

`read -rsp` so the token does not land in `.bash_history` or show up in `ps`.
