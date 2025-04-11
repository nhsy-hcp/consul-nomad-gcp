# output "load_balancer" {
#   value = module.consul-gcp.load_balancer
# }
# # output "ca_cert" {
# #     value = var.own_certs ? var.ca_cert : module.tls.vault_ca
# # }
# output "consul_nodes" {
#   value = module.consul-gcp.instances
# }
# output "instances" {
#   value = module.consul-gcp.instances_2
# }
output "hashistack_load_balancer" {
  value = google_compute_forwarding_rule.global-lb.ip_address
}
output "hashicups_load_balancer" {
  value = google_compute_forwarding_rule.clients-lb.ip_address
}

output "NOMAD_ADDR" {
  value = "http://${trimsuffix(google_dns_record_set.dns.name,".")}:4646"
}

output "CONSUL_HTTP_ADDR" {
  value = "https://${trimsuffix(google_dns_record_set.dns.name,".")}:8501"
}

output "CONSUL_TOKEN" {
  value = var.consul_bootstrap_token
  sensitive = true
}

output "NOMAD_TOKEN" {
  value = random_uuid.nomad_bootstrap.result
  sensitive = true
}

output "partitions" {
  value = [ for count in range(var.numclients) : var.consul_partitions != [""] ? element(local.admin_partitions,count) : "default" ]
}

output "eval_vars" {
  value = <<EOF
export CONSUL_HTTP_ADDR="https://${trimsuffix(google_dns_record_set.dns.name,".")}:8501"
export CONSUL_HTTP_TOKEN="${var.consul_bootstrap_token}"
export CONSUL_HTTP_SSL_VERIFY=false
export NOMAD_ADDR="http://${trimsuffix(google_dns_record_set.dns.name,".")}:4646"
export NOMAD_TOKEN="${random_uuid.nomad_bootstrap.result}"
EOF
  sensitive = true
}