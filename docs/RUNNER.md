# Runner on the ops VM

Installed by hand. Ansible takes this over later — until then these are the
commands, in order.

Nothing targets the runner yet; all workflows stay on `ubuntu-latest`. Jobs
move here only when they need something inside the VPC (Ansible, deploy).

**While the repos are public, no `runs-on: self-hosted` job may have a
`pull_request` trigger.** A fork PR would run its own code on a VM in the VPC
that hands out `cloud-platform` tokens. Dispatch and pushes to `main` only.

## SSH in

```sh
gcloud compute ssh petclinic-dev-ops \
  --project=petclinic-capstone --zone=europe-west3-a --tunnel-through-iap
```

No external IP, so it only works through the tunnel. A non-owner also needs
`roles/iap.tunnelResourceAccessor` and `roles/compute.osAdminLogin`.

## Token

GitHub → Settings → Actions → Runners → New self-hosted runner. Copy the token
from the `config.sh` line. Lasts about an hour, used once, never committed.

## Install

Own user, no sudo — jobs are arbitrary repo code and shouldn't be able to
reconfigure the host.

```sh
sudo useradd -m -s /bin/bash runner
sudo mkdir -p /opt/actions-runner
sudo chown runner:runner /opt/actions-runner

sudo -u runner -H bash
cd /opt/actions-runner

RUNNER_VERSION=2.336.0
RUNNER_SHA256=04cf0be1aff4c3ec3554466c39124ca250e3effd8873bb7e8d68535aa9505d5d

curl -sSLo actions-runner.tar.gz \
  "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
echo "${RUNNER_SHA256}  actions-runner.tar.gz" | sha256sum -c -
tar xzf actions-runner.tar.gz && rm actions-runner.tar.gz
```

Hash comes from the release notes (SHA-256 Checksums section), not from the
file you just downloaded. On a version bump copy the new one from there.

## Register

`read` so the token doesn't land in `.bash_history` or show up in `ps`.

```sh
read -rsp 'Token: ' RUNNER_TOKEN; echo

./config.sh \
  --url https://github.com/tomasevicnikola/petclinic-infra \
  --token "$RUNNER_TOKEN" \
  --name petclinic-dev-ops \
  --labels self-hosted,gcp,ops \
  --work _work \
  --disableupdate \
  --unattended

unset RUNNER_TOKEN
```

`--disableupdate` stops it replacing its own binary, so upgrades stay a
deliberate edit here.

Repo-level runner on `petclinic-infra`, so it cannot serve the app repo. That
needs its own runner or an org-level one later.

## Service

```sh
exit
cd /opt/actions-runner
sudo ./svc.sh install runner
sudo ./svc.sh start
sudo ./svc.sh status
```

Shows **Idle** under Settings → Actions → Runners. Idle is correct, nothing
targets it.

## Notes

`config.sh` leaves `.credentials` in `/opt/actions-runner`, owned by `runner` —
long-lived, and readable by any job. Not `--ephemeral` yet because nothing runs
here; worth switching when jobs do.

Destroying the VM wipes all of this and leaves an offline runner in GitHub —
delete it there by hand, then redo from the top. Deletion protection is off on
purpose so the destroy workflow keeps working.

## Remove

```sh
cd /opt/actions-runner
sudo ./svc.sh stop && sudo ./svc.sh uninstall
read -rsp 'Removal token: ' RUNNER_TOKEN; echo
sudo -u runner ./config.sh remove --token "$RUNNER_TOKEN"
unset RUNNER_TOKEN
```
