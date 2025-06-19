
locals {
  # admin_partitions = [ for i in range(var.numclients) : var.consul_partitions != [""] ? element(var.consul_partitions,i) : "default" ]
}

output "hashistack_load_balancer" {
  value = google_compute_forwarding_rule.global-lb.ip_address
}
output "apigw_load_balancers" {
  value = google_compute_forwarding_rule.clients-lb.*.ip_address
}

output "NOMAD_ADDR" {
  value = "http://${local.fqdn}:4646"
  # value = var.dns_zone != "" ? "http://${trimsuffix(google_dns_record_set.dns[0].name,".")}:4646" : "http://${google_compute_address.server_addr_int[0].address}:4646"
}

output "CONSUL_HTTP_ADDR" {
  value = "https://${local.fqdn}:8501"
  # value = var.dns_zone != "" ? "https://${trimsuffix(google_dns_record_set.dns[0].name,".")}:8501" : "https://${google_compute_address.server_addr[0].address}:8501"
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
  value = [for count in range(var.numclients) : var.consul_partitions != [""] ? element(local.admin_partitions, count) : "default"]
}

output "eval_vars" {
  value = <<EOF
export CONSUL_HTTP_ADDR="https://${local.fqdn}:8501"
export CONSUL_HTTP_TOKEN="${var.consul_bootstrap_token}"
export CONSUL_HTTP_SSL_VERIFY=false
export NOMAD_ADDR="http://${local.fqdn}:4646"
export NOMAD_TOKEN="${random_uuid.nomad_bootstrap.result}"
EOF

  #   value = <<EOF
  # export CONSUL_HTTP_ADDR="https://${trimsuffix(google_dns_record_set.dns.name,".")}:8501"
  # export CONSUL_HTTP_TOKEN="${var.consul_bootstrap_token}"
  # export CONSUL_HTTP_SSL_VERIFY=false
  # export NOMAD_ADDR="http://${trimsuffix(google_dns_record_set.dns.name,".")}:4646"
  # export NOMAD_TOKEN="${random_uuid.nomad_bootstrap.result}"
  # EOF
  sensitive = true
}

output "ingress_dashboard_url" {
  value = try("https://${trimsuffix(google_dns_record_set.ingress[0].name, ".")}:8443/dashboard/", null)
}

output "ingress_url" {
  value = try("https://${trimsuffix(google_dns_record_set.ingress[0].name, ".")}", null)
}