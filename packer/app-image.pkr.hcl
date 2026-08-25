packer {
  required_plugins {
    googlecompute = {
      version = "~> 1.1"
      source  = "github.com/hashicorp/googlecompute"
    }
    ansible = {
      version = "~> 1.1"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

variable "project_id" {
  type    = string
  default = "petclinic-capstone"
}

variable "zone" {
  type    = string
  default = "europe-west3-a"
}

# Where the builder VM runs, not where the image is used. The image is
# environment-agnostic; app-env metadata decides that at boot.
variable "subnetwork" {
  type    = string
  default = "petclinic-dev-subnet"
}

variable "image_family" {
  type    = string
  default = "petclinic-app"
}

variable "source_image_family" {
  type    = string
  default = "ubuntu-2404-lts-amd64"
}

variable "machine_type" {
  type    = string
  default = "e2-medium"
}

locals {
  stamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "googlecompute" "app" {
  project_id              = var.project_id
  zone                    = var.zone
  source_image_family     = var.source_image_family
  source_image_project_id = ["ubuntu-os-cloud"]

  machine_type = var.machine_type
  disk_size    = 20
  disk_type    = "pd-balanced"

  # Reached on its internal address: the build runs on the ops VM, in this VPC.
  # packer-build is the tag the ops-to-packer firewall rule matches.
  subnetwork       = var.subnetwork
  omit_external_ip = true
  use_internal_ip  = true
  use_iap          = false
  tags             = ["packer-build"]

  service_account_email = "sa-packer-vm@petclinic-capstone.iam.gserviceaccount.com"
  scopes                = ["https://www.googleapis.com/auth/cloud-platform"]

  ssh_username = "packer"

  pause_before_connecting = "30s"

  ssh_timeout            = "10m"
  ssh_handshake_attempts = 20

  image_name        = "${var.image_family}-${local.stamp}"
  image_family      = var.image_family
  image_description = "Ubuntu with Docker, the node exporter and the petclinic-app boot runner. The container digest is read from instance metadata at boot."

  # No environment label: one image serves every environment.
  image_labels = {
    component = "app"
    built-by  = "packer"
  }
}

build {
  name    = "app"
  sources = ["source.googlecompute.app"]

  provisioner "ansible" {
    playbook_file = "../ansible/playbooks/image.yml"
    command       = "ansible-playbook"

    extra_arguments = [
      "--extra-vars", "ansible_python_interpreter=/usr/bin/python3",
      "--scp-extra-args", "'-O'",
    ]

    # Ansible only auto-discovers ./ansible.cfg and packer runs from packer/,
    # which keeps the repository config out of the bake.
    ansible_env_vars = [
      "ANSIBLE_CONFIG=",
      "ANSIBLE_ROLES_PATH=../ansible/roles",
      "ANSIBLE_HOST_KEY_CHECKING=False",
      "ANSIBLE_NOCOLOR=True",
      "ANSIBLE_RETRY_FILES_ENABLED=False",
    ]
  }

  # Cleanup and check are one script: the cleanup removes the SSH key any later
  # provisioner would need to connect with.
  provisioner "shell" {
    execute_command = "sudo -E bash -eux '{{ .Path }}'"
    inline = [
      "echo '=== cleaning up after the build ==='",

      # Stopped first: it re-provisions authorized_keys from metadata while the
      # cleanup runs. Nothing after this point needs it.
      "systemctl stop google-guest-agent google-osconfig-agent 2>/dev/null || true",

      # Every account, not a list: the base image ships an ubuntu user too.
      "find /home /root -name authorized_keys -type f -delete 2>/dev/null || true",
      "rm -rf /home/packer/.ssh /root/.ssh",

      "rm -rf /root/.config/gcloud /home/packer/.config/gcloud",

      "rm -rf /root/.ansible /home/packer/.ansible /tmp/.ansible* /var/tmp/.ansible*",

      # Otherwise every instance shares one machine id.
      "truncate -s 0 /etc/machine-id",
      "rm -f /var/lib/dbus/machine-id",

      # cloud-init regenerates these on first boot.
      "rm -f /etc/ssh/ssh_host_*",

      "apt-get clean",
      "rm -rf /var/lib/apt/lists/*",
      "rm -rf /var/log/*.log /var/log/apt /var/log/unattended-upgrades",
      "journalctl --rotate --vacuum-time=1s >/dev/null 2>&1 || true",
      "rm -f /root/.bash_history /home/packer/.bash_history",
      "cloud-init clean --logs >/dev/null 2>&1 || true",

      "echo '=== asserting no secret material is in the image ==='",

      "SCAN='/root /home /opt /usr/local/bin /etc/systemd/system /etc/ansible /var/lib/cloud /tmp /var/tmp'",
      "FAILED=0",
      "SELF=\"$(readlink -f \"$0\")\"",

      # Filenames only, never contents: this goes to a build log.
      "report() { echo \"SECRET-CHECK FAILED: $1\" >&2; shift; printf '    %s\\n' \"$@\" >&2; FAILED=1; }",
      "scan_content() { local desc=\"$1\" pattern=\"$2\" hits; hits=\"$(grep -rlIE -- \"$pattern\" $SCAN 2>/dev/null | grep -Fxv \"$SELF\" || true)\"; [ -n \"$hits\" ] && report \"$desc\" $hits; return 0; }",

      "scan_content 'a private key is present' '^-----BEGIN [A-Z ]*PRIVATE KEY-----'",
      "scan_content 'a service account key file is present' '^[[:space:]]*\"type\"[[:space:]]*:[[:space:]]*\"service_account\"'",
      "scan_content 'an Ansible vault blob is present' '^[$]ANSIBLE_VAULT;'",
      "scan_content 'a rendered datasource password is present' '^SPRING_DATASOURCE_PASSWORD=[^%[:space:]]'",

      "HITS=\"$(find $SCAN \\( -name credentials.db -o -name access_tokens.db -o -name application_default_credentials.json \\) 2>/dev/null || true)\"",
      "[ -n \"$HITS\" ] && report 'a gcloud credential store is present' $HITS",

      "HITS=\"$(find /root /home -name authorized_keys 2>/dev/null || true)\"",
      "[ -n \"$HITS\" ] && report 'an authorized_keys file survived the cleanup' $HITS",

      "if [ -f /root/.docker/config.json ]; then",
      "  grep -q credHelpers /root/.docker/config.json || report 'docker config does not use a credential helper' /root/.docker/config.json",
      "  grep -qE '\"(auth|auths|identitytoken|password)\"' /root/.docker/config.json && report 'docker config contains an inline credential' /root/.docker/config.json",
      "fi",

      # Stopped above, but must stay enabled: it provisions OS Login on boot.
      "systemctl is-enabled google-guest-agent >/dev/null 2>&1 || report 'google-guest-agent is not enabled in the image' /lib/systemd/system/google-guest-agent.service",

      "if [ \"$FAILED\" -ne 0 ]; then echo 'refusing to publish an image containing secret material' >&2; exit 1; fi",
      "echo 'secret check passed: no credential material found in the image'",
    ]
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
