# network

Custom-mode VPC with one regional subnet, a Cloud Router and Cloud NAT for
egress, three tag-scoped ingress firewall rules, and a Private Service Access
range peered for Cloud SQL.

Exposes the network and subnet (id and self link) and the name of the PSA
range.

Nothing is reachable from the Internet: VMs get no external IP, SSH arrives
only through the IAP forwarding range, the application port is open only to
Google's health checkers, and the node exporter port only to VMs tagged `ops`.
NAT carries egress out; nothing comes back in through it.

Port 8080 on `app` instances is open to Google's health check ranges and to the
`ops` tag. The second carries both the deploy pipeline's post-release
verification and the Prometheus scrape of `/actuator/prometheus`, so monitoring
needed no new rule.

Nothing opens a port to the IAP range except 22. Grafana and Prometheus are
reached by forwarding over the existing SSH tunnel.
