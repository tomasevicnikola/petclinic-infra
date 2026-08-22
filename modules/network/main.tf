terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

locals {
  iap_range           = "35.235.240.0/20"
  health_check_ranges = ["130.211.0.0/22", "35.191.0.0/16"]

  tags = {
    ssh_iap = "ssh-iap"
    app     = "app"
    ops     = "ops"
  }

  psa_address       = split("/", var.psa_cidr)[0]
  psa_prefix_length = tonumber(split("/", var.psa_cidr)[1])
}

resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "this" {
  project       = var.project_id
  name          = var.subnet_name
  region        = var.region
  network       = google_compute_network.this.id
  ip_cidr_range = var.subnet_cidr

  private_ip_google_access = true
}

resource "google_compute_router" "this" {
  project = var.project_id
  name    = "${var.network_name}-router"
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  project = var.project_id
  name    = "${var.network_name}-nat"
  region  = var.region
  router  = google_compute_router.this.name

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.this.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_firewall" "iap_ssh" {
  project     = var.project_id
  name        = "${var.network_name}-allow-iap-ssh"
  network     = google_compute_network.this.id
  description = "SSH from the IAP TCP forwarding range only; VMs have no public IP."

  direction     = "INGRESS"
  priority      = 1000
  source_ranges = [local.iap_range]
  target_tags   = [local.tags.ssh_iap]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "health_checks" {
  project     = var.project_id
  name        = "${var.network_name}-allow-health-checks"
  network     = google_compute_network.this.id
  description = "Load balancer health probes to the application port."

  direction     = "INGRESS"
  priority      = 1000
  source_ranges = local.health_check_ranges
  target_tags   = [local.tags.app]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.app_port)]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "internal_monitoring" {
  project     = var.project_id
  name        = "${var.network_name}-allow-internal-monitoring"
  network     = google_compute_network.this.id
  description = "Prometheus node exporter scrape from the ops VM."

  direction   = "INGRESS"
  priority    = 1000
  source_tags = [local.tags.ops]
  target_tags = [local.tags.app, local.tags.ops]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.node_exporter_port)]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "ops_to_app" {
  project     = var.project_id
  name        = "${var.network_name}-allow-ops-to-app"
  network     = google_compute_network.this.id
  description = "Post-deploy verification from the ops VM against each instance's application port."

  direction   = "INGRESS"
  priority    = 1000
  source_tags = [local.tags.ops]
  target_tags = [local.tags.app]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.app_port)]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_global_address" "psa" {
  project       = var.project_id
  name          = "${var.network_name}-psa-range"
  network       = google_compute_network.this.id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = local.psa_address
  prefix_length = local.psa_prefix_length
}

resource "google_service_networking_connection" "psa" {
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa.name]
}
