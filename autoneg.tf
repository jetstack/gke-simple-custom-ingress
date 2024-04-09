module "autoneg" {
  source = "github.com/GoogleCloudPlatform/gke-autoneg-controller//terraform/gcp?ref=v1.0.0"

  project_id                    = var.project_id
  custom_role_add_random_suffix = true

  workload_identity = {
    namespace       = "autoneg-system"
    service_account = "autoneg-controller-manager"
  }
  depends_on = [module.gke]
}

resource "helm_release" "autoneg" {
  name       = "autoneg"
  chart      = "autoneg-controller-manager"
  repository = "https://googlecloudplatform.github.io/gke-autoneg-controller/"
  namespace  = "autoneg-system"

  create_namespace = true

  set {
    name  = "createNamespace"
    value = false
  }

  set {
    name  = "serviceAccount.annotations.iam\\.gke\\.io/gcp-service-account"
    value = module.autoneg.service_account_email
  }

  set {
    name  = "serviceAccount.automountServiceAccountToken"
    value = true
  }
  timeout    = 600
  wait       = true
  depends_on = [module.autoneg]
}
