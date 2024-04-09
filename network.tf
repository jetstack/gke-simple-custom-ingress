module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.0"

  project_id   = var.project_id
  network_name = "main-vpc"
  routing_mode = "GLOBAL"

  subnets = [
    {
      subnet_name   = "subnet-01"
      subnet_ip     = "10.1.0.0/16"
      subnet_region = var.region
    },
    # You will need this if you are using REGIONAL LoadBalancers, This is the range the LB will use
    {
      subnet_name   = "regional-proxy"
      subnet_ip     = "10.2.0.0/16"
      subnet_region = var.region
      purpose       = "REGIONAL_MANAGED_PROXY"
      role          = "ACTIVE"
    },
    # You will need this if you are using GLOBAL LoadBalancers, This is the range the LB will use
    {
      subnet_name   = "global-proxy"
      subnet_ip     = "10.3.0.0/16"
      subnet_region = var.region
      purpose       = "GLOBAL_MANAGED_PROXY"
      role          = "ACTIVE"
    }
  ]

  secondary_ranges = {
    subnet-01 = [
      {
        range_name    = "pods"
        ip_cidr_range = "10.4.0.0/16"
      },
      {
        range_name    = "services"
        ip_cidr_range = "10.5.0.0/16"
      }
    ]
  }
}

module "cloud-nat" {
  source        = "terraform-google-modules/cloud-nat/google"
  version       = "~> 1.2"
  project_id    = var.project_id
  region        = var.region
  router        = "safer-router"
  network       = module.vpc.network_name
  create_router = true
}
