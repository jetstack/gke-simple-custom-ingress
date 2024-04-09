locals {
  external_dns_domain = trimsuffix(data.google_dns_managed_zone.managed_zone_external.dns_name, ".")
}

//Create Health Check to ensure the service is healthy
resource "google_compute_health_check" "frontend_external" {
  name        = "frontend-external"
  description = "frontend-external"

  timeout_sec         = 10
  check_interval_sec  = 60
  healthy_threshold   = 4
  unhealthy_threshold = 5

  http_health_check {
    port_specification = "USE_SERVING_PORT"
    request_path       = "/_healthz"
  }
}

//Create our Blue Backend Service for Blue
resource "google_compute_backend_service" "blue_external" {
  project               = var.project_id
  name                  = "blue-external"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks         = [google_compute_health_check.frontend_external.id]
  lifecycle {
    ignore_changes = [backend]
  }
}

//Create our Blue Backend Service for Green
resource "google_compute_backend_service" "green_external" {
  project               = var.project_id
  name                  = "green-external"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks         = [google_compute_health_check.frontend_external.id]
  lifecycle {
    ignore_changes = [backend]
  }
}

// Global External LoadBalancers only support Classic SSL Certificates
// This means Wildcards are not supported
// This means you have to create a resource for each ingress point
resource "google_compute_managed_ssl_certificate" "external_ssl_cert" {
  name = "external-ssl-cert"

  managed {
    domains = [local.external_dns_domain]
  }
}

resource "google_compute_managed_ssl_certificate" "color_external" {
  for_each = toset(["blue", "green"])
  name     = "${each.value}-external-cert"

  managed {
    domains = ["${each.value}.${local.external_dns_domain}"]
  }
}

// Use google_compute_target_http_proxy if you don't require SSL
// This will form the frontend of our loadbalancer
resource "google_compute_target_https_proxy" "external_global_https_proxy" {
  name    = "external-global-target-proxy"
  url_map = google_compute_url_map.external_global_http_url_map.id
  ssl_certificates = [
    google_compute_managed_ssl_certificate.external_ssl_cert.id,
    google_compute_managed_ssl_certificate.color_external["blue"].id,
    google_compute_managed_ssl_certificate.color_external["green"].id
  ]
}

// Create Google Compute URL Map
// This will be used on the LoadBalancer to determine routing
resource "google_compute_url_map" "external_global_http_url_map" {
  name            = "external"
  description     = "external"
  default_service = google_compute_backend_service.blue_external.name

  host_rule {
    hosts        = [local.external_dns_domain]
    path_matcher = "blue"
  }

  host_rule {
    hosts        = ["blue-${local.external_dns_domain}"]
    path_matcher = "blue"
  }

  host_rule {
    hosts        = ["green-${local.external_dns_domain}"]
    path_matcher = "green"
  }

  path_matcher {
    name            = "blue"
    default_service = google_compute_backend_service.blue_external.id
  }
  path_matcher {
    name            = "green"
    default_service = google_compute_backend_service.blue_external.id
  }
}

// Create Static IP Address
resource "google_compute_global_address" "ip_address_external" {
  name = "external-address"
}

//Creating Forwarding Rule
// This will form the Google LoadBalancer its-self
resource "google_compute_global_forwarding_rule" "external_global_http_forwarding_rule" {
  name                  = "external-lb"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.ip_address_external.address
  port_range            = "443"
  target                = google_compute_target_https_proxy.external_global_https_proxy.id
}

//Create Firewall Rule to allow GCP Probes to Access our Health Checks
resource "google_compute_firewall" "external-lb-hc" {
  name        = "external-allow-lb-health-check"
  network     = module.vpc.network_name
  target_tags = ["allow-health-checks"]
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ]
  allow {
    protocol = "tcp"
    ports    = ["80", "8080"]
  }
}

#
# DNS Resources
#

data "google_dns_managed_zone" "managed_zone_external" {
  name = var.dns_external_domain_name
}

resource "google_dns_record_set" "external" {
  managed_zone = data.google_dns_managed_zone.managed_zone_external.name
  name         = data.google_dns_managed_zone.managed_zone_external.dns_name
  rrdatas      = [google_compute_global_address.ip_address_external.address]
  type         = "A"
}

resource "google_dns_record_set" "wildcard_external" {
  managed_zone = data.google_dns_managed_zone.managed_zone_external.name
  name         = "*.${data.google_dns_managed_zone.managed_zone_external.dns_name}"
  rrdatas      = [google_compute_global_address.ip_address_external.address]
  type         = "A"
}
