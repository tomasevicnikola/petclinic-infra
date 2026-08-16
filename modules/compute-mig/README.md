# compute-mig

A regional managed instance group for the application: instance template, HTTP
health check, CPU autoscaler. Instances are private and Shielded, run as
`sa-app-vm`, and carry the `ssh-iap` and `app` tags the network module's
firewall rules match on.

Exposes the instance group self link a load balancer backend takes, the health
check, the group manager name and the named port.

A new instance boots without the application on it — the startup script only
enables unattended upgrades, and installing Docker and running the container is
Ansible's job. That is why autohealing is off: a health check against an app
that was never installed would recreate instances forever. The group is regional
and `min_replicas = 2`, so two instances land in different zones and losing one
zone leaves it serving.
