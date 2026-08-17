terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

locals {
  self_signed = var.domain == null

  ssl_certificate = local.self_signed ? google_compute_ssl_certificate.this[0].id : google_compute_managed_ssl_certificate.this[0].id

  sslip_host = "${google_compute_global_address.this.address}.sslip.io"
  host       = local.self_signed ? google_compute_global_address.this.address : var.domain
}

resource "google_compute_global_address" "this" {
  project      = var.project_id
  name         = "${var.name_prefix}-ip"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

resource "google_compute_backend_service" "this" {
  project     = var.project_id
  name        = "${var.name_prefix}-backend"
  description = "Application backend. Reports UNHEALTHY until the instances actually run the app."

  protocol              = "HTTP"
  port_name             = var.port_name
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = var.backend_timeout_sec

  health_checks = [var.health_check_self_link]

  iap {
    enabled = true
  }

  backend {
    group           = var.instance_group
    balancing_mode  = "UTILIZATION"
    max_utilization = var.max_utilization
    capacity_scaler = 1.0
  }

  log_config {
    enable      = true
    sample_rate = var.log_sample_rate
  }
}

resource "google_iap_web_backend_service_iam_member" "this" {
  for_each = toset(var.allowed_members)

  project             = var.project_id
  web_backend_service = google_compute_backend_service.this.name
  role                = "roles/iap.httpsResourceAccessor"
  member              = each.value
}

resource "google_compute_url_map" "this" {
  project         = var.project_id
  name            = "${var.name_prefix}-urlmap"
  default_service = google_compute_backend_service.this.id
}

resource "google_compute_url_map" "redirect" {
  project = var.project_id
  name    = "${var.name_prefix}-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_ssl_policy" "this" {
  project         = var.project_id
  name            = "${var.name_prefix}-ssl-policy"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

resource "tls_private_key" "this" {
  count = local.self_signed ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "this" {
  count = local.self_signed ? 1 : 0

  private_key_pem       = tls_private_key.this[0].private_key_pem
  validity_period_hours = var.self_signed_validity_hours
  early_renewal_hours   = 168

  dns_names    = [local.sslip_host]
  ip_addresses = [google_compute_global_address.this.address]

  subject {
    common_name  = local.sslip_host
    organization = var.name_prefix
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "google_compute_ssl_certificate" "this" {
  count = local.self_signed ? 1 : 0

  project     = var.project_id
  name_prefix = "${var.name_prefix}-cert-"
  private_key = tls_private_key.this[0].private_key_pem
  certificate = tls_self_signed_cert.this[0].cert_pem

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_managed_ssl_certificate" "this" {
  count = local.self_signed ? 0 : 1

  project = var.project_id
  name    = "${var.name_prefix}-managed-cert-${substr(sha1(var.domain), 0, 6)}"

  managed {
    domains = [var.domain]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_target_https_proxy" "this" {
  project = var.project_id
  name    = "${var.name_prefix}-https-proxy"

  url_map          = google_compute_url_map.this.id
  ssl_certificates = [local.ssl_certificate]
  ssl_policy       = google_compute_ssl_policy.this.id
}

resource "google_compute_target_http_proxy" "redirect" {
  project = var.project_id
  name    = "${var.name_prefix}-http-proxy"
  url_map = google_compute_url_map.redirect.id
}

resource "google_compute_global_forwarding_rule" "https" {
  project = var.project_id
  name    = "${var.name_prefix}-https"

  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.this.id
  port_range            = "443"
  target                = google_compute_target_https_proxy.this.id
}

resource "google_compute_global_forwarding_rule" "http" {
  project = var.project_id
  name    = "${var.name_prefix}-http"

  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.this.id
  port_range            = "80"
  target                = google_compute_target_http_proxy.redirect.id
}
