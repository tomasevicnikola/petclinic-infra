terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

resource "google_compute_instance" "this" {
  project      = var.project_id
  name         = var.instance_name
  zone         = var.zone
  machine_type = var.machine_type

  tags = var.network_tags

  boot_disk {
    initialize_params {
      image = var.boot_image
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = var.subnet_id
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive

    for _ in $(seq 1 10); do
      if apt-get update && apt-get install -y unattended-upgrades; then
        break
      fi
      sleep 15
    done

    printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n' \
      > /etc/apt/apt.conf.d/20auto-upgrades
    systemctl enable --now unattended-upgrades
  EOT

  allow_stopping_for_update = true
}
