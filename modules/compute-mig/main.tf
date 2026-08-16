terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

locals {
  named_port         = "http"
  base_instance_name = coalesce(var.base_instance_name, var.name_prefix)
}

resource "google_compute_instance_template" "this" {
  project      = var.project_id
  name_prefix  = "${var.name_prefix}-"
  machine_type = var.machine_type

  tags = var.network_tags

  disk {
    source_image = var.boot_image
    disk_size_gb = var.boot_disk_size_gb
    disk_type    = "pd-balanced"
    boot         = true
    auto_delete  = true
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

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_health_check" "this" {
  project = var.project_id
  name    = "${var.name_prefix}-hc"

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = var.app_port
    request_path = var.health_check_path
  }

  log_config {
    enable = true
  }
}

resource "google_compute_region_instance_group_manager" "this" {
  project = var.project_id
  region  = var.region
  name    = "${var.name_prefix}-mig"

  base_instance_name = local.base_instance_name

  version {
    instance_template = google_compute_instance_template.this.self_link_unique
  }

  named_port {
    name = local.named_port
    port = var.app_port
  }

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = var.max_surge
    max_unavailable_fixed = 0
  }

  dynamic "auto_healing_policies" {
    for_each = var.enable_autohealing ? [1] : []

    content {
      health_check      = google_compute_health_check.this.id
      initial_delay_sec = var.autohealing_initial_delay_sec
    }
  }
}

resource "google_compute_region_autoscaler" "this" {
  project = var.project_id
  region  = var.region
  name    = "${var.name_prefix}-autoscaler"
  target  = google_compute_region_instance_group_manager.this.id

  autoscaling_policy {
    min_replicas    = var.min_replicas
    max_replicas    = var.max_replicas
    cooldown_period = var.cooldown_period_sec

    cpu_utilization {
      target = var.cpu_target
    }
  }
}
