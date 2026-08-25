# compute-mig

A regional managed instance group for the application: instance template, two
health checks, CPU autoscaler. Instances are private and Shielded, run as
`sa-app-vm`, and carry the `ssh-iap` and `app` tags the network module's
firewall rules match on.

Instances boot from the `petclinic-app` image, baked by Packer from the Ansible
roles. There is no startup script and nothing configures an instance after boot.

The container is not in the image. Two metadata keys carry it:

| Key | From | Read by |
| --- | --- | --- |
| `app-image-digest` | `var.app_image_digest` | `petclinic-app-run.sh` on first boot |
| `app-env` | `var.app_env` | same, to pick `<env>-db-app-*` secrets |

So a deploy is a new template plus a rolling replace. `var.app_image` is null by
default, which tracks the image family; set it to an exact image to pin one.

Two health checks: `this` is the load balancer's (3 × 10s), `autohealing` is the
group's (5 × 30s, 240s initial delay). Separate because taking an instance out
of the pool is cheaper than destroying it. Autohealing is on.

The image itself is built by `packer/` and `ansible/playbooks/image.yml`; this
module only boots it.
