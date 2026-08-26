# monitoring_stack

Prometheus and Grafana as a Docker Compose project on the ops VM.
Ops VM only; not baked into the application image.

```sh
cd ansible
ansible-playbook playbooks/ops.yml --tags monitoring_stack
```

| Component | Listens on |
| --- | --- |
| Prometheus | `127.0.0.1:9090` |
| Grafana | `127.0.0.1:3000` |

Images pinned by tag and digest in `defaults/main.yml`. No firewall rule was
added: `ops` → `app` on 8080 already existed for deploy verification.

Reaching the UIs means forwarding ports over the IAP SSH tunnel —
`docs/monitoring.md` has the command. `gcloud compute start-iap-tunnel <vm> 3000`
would not work: IAP forwards to the VM's internal address, not loopback, so it
would need a new firewall rule and Grafana bound to the wire.

## Scrape jobs

| Job | Targets | Discovery |
| --- | --- | --- |
| `node` | app VMs `:9100` | GCE SD, tag `app` |
| `petclinic-app` | app VMs `:8080/actuator/prometheus` | GCE SD, tag `app` |
| `node-ops` | ops VM `:9100` | static |
| `monitoring` | the three containers | static |

The `env` label comes from `app-env` instance metadata, so instances in a new
environment appear on their own — nothing to change here, nothing to re-run when
qa comes up.

Availability from outside the VPC is not measured here. That is the Cloud
Monitoring uptime check in `modules/cloud-monitoring`, which needs no credential
on this VM.

## Dashboards

Two, committed as JSON in `files/dashboards/` and provisioned read-only: Node /
VM overview, JVM / application. HTTP latency is a mean — Micrometer publishes no
histogram buckets by default.

## Secrets

Grafana's password is read from Secret Manager at container start and passed in
the environment; the compose file uses `${GF_SECURITY_ADMIN_PASSWORD:?}`, so a
failed read stops the stack instead of falling back to `admin/admin`.

**Nothing is written to disk.** Service discovery uses the instance's own
credentials from the metadata server: no service account key, no token file, no
vault content in this role.

## One trap

**`ExecStop` passes no `--file`.** Compose interpolates the compose file for
every command including `down`, and `ExecStop` has no
`GF_SECURITY_ADMIN_PASSWORD` — with `--file`, stop fails silently and the stack
keeps serving its old configuration.
