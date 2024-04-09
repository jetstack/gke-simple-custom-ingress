data "google_compute_zones" "available" {
  region = var.region
}

data "google_client_config" "provider" {}

data "google_container_cluster" "cluster" {
  name     = module.gke.name
  location = module.gke.location
}


