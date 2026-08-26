# Monitoring

## What runs

Prometheus and Grafana as one Docker Compose project on the **dev** ops VM,
installed by `ansible/roles/monitoring_stack`. Images pinned by tag and digest.

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

One, provisioned from JSON committed in the role, with an `env` selector.

| Dashboard | Contents |
| --- | --- |
| PetClinic - rollout & health | instances serving over time, requests/s, 5xx share, heap; CPU, memory and root disk per VM |

`Instances over time` is drawn stepped. `refresh` is 10s over a 30-minute
window, against a 15s scrape.

`node-overview.json` and `jvm-app.json` remain in
`roles/monitoring_stack/files/dashboards/` and are not provisioned. List either
in `roles/monitoring_stack/vars/main.yml` to bring it back.

Uptime probes are answered by IAP at the load balancer and never reach the
application, so `Requests per second` and `5xx share` only move under real
traffic.

## Alerts

Alerting is Cloud Monitoring's job, below. Prometheus and Grafana collect and
show; nothing here evaluates thresholds or notifies, so no SMTP credential
exists in the project — Google sends the mail.

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
  -N -L 3000:localhost:3000 -L 9090:localhost:9090
```

Leave it running; `localhost` in `-L` resolves **on the VM**, which is where the
services are bound. Then Grafana is on 3000 and Prometheus on 9090. Sign in as
`admin`:

```sh
gcloud secrets versions access latest --secret=dev-grafana-admin-password
```

Collection and alerting do not depend on the tunnel — it is a viewing window,
not the mechanism. The Cloud Monitoring dashboard needs no tunnel at all.

## Network

No firewall rule was added. The `ops` → `app` rule on 8080 already existed for
deploy verification and carries the actuator scrape too. Port 22 remains the
only port open to the IAP range.
