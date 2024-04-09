# Get Application Manifests
data "kubectl_file_documents" "applications" {
  content = file("${path.module}/applications.yaml")
}

# Deploy Applications
resource "kubectl_manifest" "applications" {
  for_each   = data.kubectl_file_documents.applications.manifests
  yaml_body  = each.value
  depends_on = [module.gke]
}
