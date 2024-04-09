variable "project_id" {
  type        = string
  description = "ID for Project"
  default     = ""
}

variable "region" {
  type        = string
  description = "Region for Resources"
  default     = "europe-west2"
}

variable "dns_external_domain_name" {
  type        = string
  description = "DNS Domain Name for External Ingress"
  default     = ""
}

variable "dns_internal_domain_name" {
  type        = string
  description = "DNS Domain Name for Internal Ingress"
  default     = ""
}
