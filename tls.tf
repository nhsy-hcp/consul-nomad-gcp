# resource "google_compute_managed_ssl_certificate" "nomad_consul" {
#   name        = "${var.cluster_name}-global-cert"
#   description = "Managed SSL certificate for Nomad and Consul"
#   managed {
#     domains = [
#       "nomad.${var.cluster_name}.${data.google_dns_managed_zone.doormat_dns_zone[0].dns_name}",
#       "consul.${var.cluster_name}.${data.google_dns_managed_zone.doormat_dns_zone[0].dns_name}",
#     ]
#   }
# }

resource "google_compute_ssl_certificate" "nomad_consul" {
  name        = "${var.cluster_name}-tls-cert"
  description = "TLS certificate for Nomad and Consul"

  private_key = acme_certificate.default.private_key_pem
  certificate = "${acme_certificate.default.certificate_pem}${acme_certificate.default.issuer_pem}"
}
