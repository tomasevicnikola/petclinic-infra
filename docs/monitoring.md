# Monitoring

## What runs

Prometheus, Grafana and Alertmanager as one Docker Compose project on the **dev**
ops VM, installed by `ansible/roles/monitoring_stack`. Images pinned by tag and
digest.

One stack serves every environment: app VMs are found by GCE service discovery
and carry an `env` label from their `app-env` instance metadata, so a new
environment appears on its own.

## What is collected

| Source | Metrics |
| --- | --- |
| `node_exporter` on every app VM | CPU, memory, disk, network |
| `/actuator/prometheus` on every app VM | JVM heap, GC, HTTP, HikariCP, log events |
| `node_exporter` on the ops VM | same, for the ops VM |
| the three containers | the monitoring stack itself |
| Cloud Monitoring uptime check | the load balancer, from outside the VPC |

## Grafana dashboards

Two, provisioned from JSON committed in the role. Each has an `env` selector.

| Dashboard | Contents |
| --- | --- |
| Node / VM overview | CPU, load, memory, disk, network per VM, plus scrape health |
| JVM / application | request rate, latency, errors, heap, GC, connection pool, log event rate |

## Alerts

Six Prometheus rules — `InstanceDown`, `HighCPU`, `HighMemory`, `AppHealthDown`,
`HighJvmHeap`, `MonitoringDown` — read in Alertmanager, which groups, inhibits
and silences them.

`AppHealthDown` watches the actuator scrape on each instance. Reachability from
outside is the uptime check's job, so no credential has to live on the ops VM to
ask that question.

**Prometheus records, Cloud Monitoring notifies.** Alertmanager has no delivery
target; email comes from the policies below, so no SMTP credential exists here.

## Cloud Monitoring

One dashboard, one uptime check and three alert policies per environment, from
metrics Google emits itself — `modules/cloud-monitoring` installs nothing.

- Dashboards → *PetClinic dev — GCP view* — application uptime, VM CPU, database
  queries and latency
- Uptime checks → *petclinic-dev — load balancer reachable*
- Alerting → *high CPU* / *application downtime* / *application unreachable*

All three policies email; the address comes from the `CLOUD_MONITORING_EMAIL`
repository variable and is never committed.

The uptime check is **unauthenticated on purpose** and expects IAP's `302`. That
proves DNS, TLS, the forwarding rule and that IAP is still enforcing, with no ID
token anywhere. A `200` would mean IAP had been switched off.

## Access

Grafana binds loopback and is not public. Reach it by forwarding ports over the
SSH session IAP already permits:

```sh
gcloud compute ssh petclinic-dev-ops \
  --project=petclinic-capstone --zone=europe-west3-a --tunnel-through-iap -- \
  -N -L 3000:localhost:3000 -L 9090:localhost:9090 -L 9093:localhost:9093
```

Leave it running; `localhost` in `-L` resolves **on the VM**, which is where the
services are bound. Then Grafana is on 3000, Prometheus 9090, Alertmanager 9093.
Sign in as `admin`:

```sh
gcloud secrets versions access latest --secret=dev-grafana-admin-password
```

Collection and alerting do not depend on the tunnel — it is a viewing window,
not the mechanism. The Cloud Monitoring dashboard needs no tunnel at all.

## Network

No firewall rule was added. The `ops` → `app` rule on 8080 already existed for
deploy verification and carries the actuator scrape too. Port 22 remains the
only port open to the IAP range.
