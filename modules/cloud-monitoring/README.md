# cloud-monitoring

One dashboard, one uptime check and three alert policies per environment.
Exposes the dashboard id, the uptime check id and the policy names.

Nothing is installed and nothing runs: every series comes from the hypervisor,
the load balancer or Cloud SQL, which Google emits on its own.

## What it covers

**Reachability, from outside the VPC** — an uptime check against the load
balancer and the `application unreachable` policy on it. Google's probers run on
their own schedule, so unlike the 5xx policy this fires on a quiet system too.

It is **unauthenticated on purpose** and expects IAP's `302` to the sign-in page.
That proves DNS, TLS, the forwarding rule and that IAP is still enforcing; a
`200` would mean IAP had been switched off, which this then catches. Proving the
application behind IAP is serving would need an ID token to exist somewhere —
that question is answered by Prometheus scraping each actuator instead.
`validate_ssl` is off because the certificate is self-signed for the sslip.io
name.

**Database queries and latency** — `mysql/queries`, `mysql/slow_queries_count`
and the InnoDB lock counters. The application exposes its connection pool and
nothing about queries, so this is the only place they exist.

**CPU, from outside the guest** — measured by the hypervisor, so a wedged or
dead VM cannot suppress it the way an in-guest exporter would.

## What it cannot cover

Memory, disk and logs. All three need the Ops Agent inside the guest, and no VM
here runs one. `node_exporter` reports memory and disk to Prometheus instead;
the dashboard says so on a text tile rather than leaving an empty chart.

## The downtime policy needs traffic

It counts 5xx at the load balancer, so an application that is down on a quiet
system produces no requests and no incident. Read it as "users are being served
errors". The traffic-independent signal is the uptime check above, which runs
on Google's schedule whether or not anyone is using the system.

## Notifications

All three policies email. The address comes from the `CLOUD_MONITORING_EMAIL`
repository variable, passed as `TF_VAR_cloud_monitoring_notification_email`, so
it is never committed to this public repository. Empty or unset creates no
channel and incidents stay in the console.

Google sends the mail, so no SMTP credential exists anywhere in the project.

## Scoping

| Source | Scoped by |
| --- | --- |
| Load balancer | `resource.label.url_map_name` |
| Cloud SQL | `resource.label.database_id` |
| VMs | `metric.label.instance_name` starts_with the environment prefix |
| Uptime check | `metric.label.check_id`, from the check this module creates |
