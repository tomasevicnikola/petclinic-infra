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
`ops` tag. The second is what lets the deploy pipeline verify each instance
directly after a release.
