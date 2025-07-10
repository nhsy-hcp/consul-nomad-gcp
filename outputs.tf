
locals {
  # admin_partitions = [ for i in range(var.numclients) : var.consul_partitions != [""] ? element(var.consul_partitions,i) : "default" ]
}

# output "hashistack_load_balancer" {
#   value = google_compute_forwarding_rule.global-lb.ip_address
# }

output "apigw_load_balancers" {
  value = google_compute_forwarding_rule.clients-lb.*.ip_address
}

output "NOMAD_ADDR" {
  value = local.nomad_https_url
}

output "CONSUL_HTTP_ADDR" {
  value = local.consul_https_url
}

output "CONSUL_TOKEN" {
  value     = var.consul_bootstrap_token
  sensitive = true
}

output "NOMAD_TOKEN" {
  value     = random_uuid.nomad_bootstrap.result
  sensitive = true
}

output "partitions" {
  value = [for count in range(var.nomad_clients) : var.consul_partitions != [""] ? element(local.admin_partitions, count) : "default"]
}

output "eval_vars" {
  value     = <<EOF
export CONSUL_HTTP_ADDR="${local.consul_https_url}"
export CONSUL_HTTP_TOKEN="${var.consul_bootstrap_token}"
export CONSUL_HTTP_SSL_VERIFY=false
export NOMAD_ADDR="${local.nomad_https_url}"
export NOMAD_TOKEN="${random_uuid.nomad_bootstrap.result}"
export NOMAD_SKIP_VERIFY=true
export GCP_PROJECT="${var.gcp_project}"
export GCP_WI_PROVIDER="${google_iam_workload_identity_pool_provider.nomad_provider.name}"
export GCP_WI_SERVICE_ACCOUNT="${google_service_account.nomad.email}"
EOF
  sensitive = true
}

output "ingress_dashboard_url" {
  value = try("https://${trimsuffix(google_dns_record_set.ingress[0].name, ".")}:8443/dashboard/", null)
}

output "ingress_url" {
  value = try("https://${trimsuffix(google_dns_record_set.ingress[0].name, ".")}", null)
}

output "ingress_fqdn" {
  value = try("${trimsuffix(google_dns_record_set.ingress[0].name, ".")}", null)
}

output "gcp_project" {
  value = var.gcp_project
}

output "gcp_wi_provider" {
  value = google_iam_workload_identity_pool_provider.nomad_provider.name
}

output "gcp_wi_service_account" {
  value = google_service_account.nomad.email
}