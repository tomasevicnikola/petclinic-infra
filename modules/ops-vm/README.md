# ops-vm

A single Ubuntu 24.04 instance for tooling: the self-hosted GitHub Actions
runner now, the monitoring stack later.

Exposes the instance name, zone and internal IP.

No external IP, so it is reachable only through IAP SSH on the `ssh-iap` tag
and reaches the Internet only outbound through Cloud NAT. Shielded VM and OS
Login are on. Terraform installs nothing beyond OS updates — the runner and
everything after it are Ansible's job.
