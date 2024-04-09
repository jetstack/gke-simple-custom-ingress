module "gke" {
  source                     = "terraform-google-modules/kubernetes-engine/google//modules/beta-autopilot-private-cluster"
  version                    = "30.0.0"
  project_id                 = var.project_id
  name                       = "autopilot-cluster-1"
  region                     = var.region
  zones                      = data.google_compute_zones.available.names
  network                    = module.vpc.network_name
  subnetwork                 = module.vpc.subnets["europe-west2/subnet-01"].name
  ip_range_pods              = "pods"
  ip_range_services          = "services"
  horizontal_pod_autoscaling = true
  enable_private_nodes       = true
  network_tags = [
    "allow-health-checks"
  ]
  deletion_protection = false
  master_authorized_networks = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "AllowAny"
    }
  ]
}
