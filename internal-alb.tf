locals {
  internal_dns_domain = trimsuffix(data.google_dns_managed_zone.managed_zone_internal.dns_name, ".")
}

//Create Health Check to ensure the service is healthy
resource "google_compute_health_check" "frontend_internal" {
  name        = "frontend-internal"
  description = "frontend-internal"

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
resource "google_compute_backend_service" "blue_internal" {
  project               = var.project_id
  name                  = "blue-internal"
  load_balancing_scheme = "INTERNAL_MANAGED"
  health_checks         = [google_compute_health_check.frontend_internal.id]
  lifecycle {
    ignore_changes = [backend]
  }
}

//Create our Blue Backend Service for Green
resource "google_compute_backend_service" "green_internal" {
  project               = var.project_id
  name                  = "green-internal"
  load_balancing_scheme = "INTERNAL_MANAGED"
  health_checks         = [google_compute_health_check.frontend_internal.id]
  lifecycle {
    ignore_changes = [backend]
  }
}

//Create DNS Authorization
// You only need this if your cert will be wildcards
resource "google_certificate_manager_dns_authorization" "internal_dns_auth" {
  name        = "dns-auth"
  description = "DNS"
  domain      = local.internal_dns_domain
}

//We can use Google New Certificates for Internal LoadBalancers
resource "google_certificate_manager_certificate" "internal_certificate" {
  name        = "internal-cert"
  description = "Internal Domain certificate"
  scope       = "ALL_REGIONS"
  managed {
    domains = [
      google_certificate_manager_dns_authorization.internal_dns_auth.domain,
      "*.${google_certificate_manager_dns_authorization.internal_dns_auth.domain}",

    ]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.internal_dns_auth.id,
    ]
  }
}

// Use google_compute_target_http_proxy if you don't require SSL
// This will form the frontend of our loadbalancer
resource "google_compute_target_https_proxy" "internal_global_https_proxy" {
  name                             = "internal-global-target-proxy"
  url_map                          = google_compute_url_map.internal_global_http_url_map.id
  certificate_manager_certificates = [google_certificate_manager_certificate.internal_certificate.id]
}

// Create Google Compute URL Map
// This will be used on the LoadBalancer to determine routing
resource "google_compute_url_map" "internal_global_http_url_map" {
  name            = "internal"
  description     = "internal"
  default_service = google_compute_backend_service.blue_internal.name

  host_rule {
    hosts        = [local.internal_dns_domain]
    path_matcher = "blue"
  }

  host_rule {
    hosts        = ["blue-${local.internal_dns_domain}"]
    path_matcher = "blue"
  }

  host_rule {
    hosts        = ["green-${local.internal_dns_domain}"]
    path_matcher = "green"
  }

  path_matcher {
    name            = "blue"
    default_service = google_compute_backend_service.blue_internal.id
  }
  path_matcher {
    name            = "green"
    default_service = google_compute_backend_service.blue_internal.id
  }
}

// Create Static IP Address
resource "google_compute_address" "ip_address_internal" {
  subnetwork   = module.vpc.subnets["europe-west2/subnet-01"].name
  address_type = "INTERNAL"
  name         = "internal-address"
}

// Creating Forwarding Rule
// This will form the Google LoadBalancer its-self
resource "google_compute_global_forwarding_rule" "internal_global_http_forwarding_rule" {
  name                  = "internal-lb"
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  ip_address            = google_compute_address.ip_address_internal.id
  port_range            = "443"
  network               = module.vpc.network_name
  target                = google_compute_target_https_proxy.internal_global_https_proxy.id
}

//Create Firewall Rule to allow GCP Probes to Access our Health Checks
resource "google_compute_firewall" "internal-lb-hc" {
  name        = "internal-allow-lb-health-check"
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

data "google_dns_managed_zone" "managed_zone_internal" {
  name = var.dns_internal_domain_name
}

resource "google_dns_record_set" "internal" {
  managed_zone = data.google_dns_managed_zone.managed_zone_internal.name
  name         = data.google_dns_managed_zone.managed_zone_internal.dns_name
  rrdatas      = [google_compute_address.ip_address_internal.address]
  type         = "A"
}

resource "google_dns_record_set" "wildcard_internal" {
  managed_zone = data.google_dns_managed_zone.managed_zone_internal.name
  name         = "*.${data.google_dns_managed_zone.managed_zone_internal.dns_name}"
  rrdatas      = [google_compute_address.ip_address_internal.address]
  type         = "A"
}
