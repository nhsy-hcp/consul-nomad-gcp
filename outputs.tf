locals {
  # admin_partitions = [ for i in range(var.numclients) : var.consul_partitions != [""] ? element(var.consul_partitions,i) : "default" ]
}

# output "hashistack_load_balancer" {
#   value = google_compute_forwarding_rule.global-lb.ip_address
# }

output "apigw_load_balancers" {
  description = "IP addresses of the API gateway load balancers"
  value       = var.nomad_clients > 0 ? google_compute_forwarding_rule.clients_lb[*].ip_address : []
}

# tflint-ignore: terraform_naming_convention
output "NOMAD_ADDR" {
  description = "Nomad HTTPS URL for API access"
  value       = local.nomad_https_url
}

# tflint-ignore: terraform_naming_convention
output "CONSUL_HTTP_ADDR" {
  description = "Consul HTTPS URL for API access"
  value       = local.consul_https_url
}

# tflint-ignore: terraform_naming_convention
output "CONSUL_TOKEN" {
  description = "Consul bootstrap token for authentication"
  value       = var.consul_bootstrap_token
  sensitive   = true
}

# tflint-ignore: terraform_naming_convention
output "NOMAD_TOKEN" {
  description = "Nomad bootstrap token for authentication"
  value       = random_uuid.nomad_bootstrap.result
  sensitive   = true
}

output "partitions" {
  description = "List of Consul admin partitions assigned to Nomad clients"
  value       = [for count in range(var.nomad_clients) : var.consul_partitions != [""] ? element(local.admin_partitions, count) : "default"]
}

output "eval_vars" {
  description = "Environment variables for Consul and Nomad CLI access"
  value       = <<EOF
export CONSUL_HTTP_ADDR="${local.consul_https_url}"
export CONSUL_HTTP_TOKEN="${var.consul_bootstrap_token}"
export CONSUL_HTTP_SSL_VERIFY=false
export NOMAD_ADDR="${local.nomad_https_url}"
export NOMAD_TOKEN="${random_uuid.nomad_bootstrap.result}"
export NOMAD_SKIP_VERIFY=true
EOF
  sensitive   = true
}

output "ingress_dashboard_url" {
  description = "URL for accessing the Traefik dashboard"
  value       = try("https://${trimsuffix(google_dns_record_set.ingress[0].name, ".")}:8443/dashboard/", null)
}

output "ingress_url" {
  description = "Base HTTPS URL for the ingress endpoint"
  value       = try("https://${trimsuffix(google_dns_record_set.ingress[0].name, ".")}", null)
}

output "ingress_fqdn" {
  description = "Fully qualified domain name for the ingress endpoint"
  value       = try(trimsuffix(google_dns_record_set.ingress[0].name, "."), null)
}

output "gcp_project" {
  description = "GCP project ID where resources are deployed"
  value       = var.gcp_project
}

output "gcp_region" {
  description = "GCP region where resources are deployed"
  value       = var.gcp_region
}

output "cluster_name" {
  description = "Cluster name used as a prefix for GCP resources"
  value       = var.cluster_name
}

output "gcp_wi_provider" {
  description = "GCP Workload Identity provider name for Nomad"
  value       = google_iam_workload_identity_pool_provider.nomad_provider.name
}

output "gcp_wi_demo_service_account" {
  description = "Email of the GCP service account for workload identity demo"
  value       = google_service_account.wi_demo.email
}

output "monte_carlo_bucket" {
  description = "Name of the GCS bucket for Monte Carlo simulation results"
  value       = google_storage_bucket.monte_carlo.name
}

output "gcp_wi_monte_carlo_service_account" {
  description = "Email of the GCP service account for Monte Carlo workloads"
  value       = google_service_account.monte_carlo.email
}

output "gcp_wi_csi_google_pd_service_account" {
  description = "Email of the GCP service account for CSI Google PD driver"
  value       = google_service_account.gce_pd_csi.email
}


output "letsencrypt_email" {
  description = "Email address for Let's Encrypt certificate registration"
  value       = var.letsencrypt_email
}
