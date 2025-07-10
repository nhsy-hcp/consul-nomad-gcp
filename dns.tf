data "google_dns_managed_zone" "doormat_dns_zone" {
  count = var.dns_zone != "" ? 1 : 0
  name  = var.dns_zone
}

resource "google_dns_record_set" "nomad" {
  count = var.dns_zone != "" ? 1 : 0
  name  = "nomad.${var.cluster_name}.${data.google_dns_managed_zone.doormat_dns_zone[0].dns_name}"
  type  = "A"
  ttl   = 300

  managed_zone = data.google_dns_managed_zone.doormat_dns_zone[0].name

  rrdatas = [google_compute_global_address.nomad_consul.address]
}

resource "google_dns_record_set" "consul" {
  count = var.dns_zone != "" ? 1 : 0
  name  = "consul.${var.cluster_name}.${data.google_dns_managed_zone.doormat_dns_zone[0].dns_name}"
  type  = "A"
  ttl   = 300

  managed_zone = data.google_dns_managed_zone.doormat_dns_zone[0].name

  rrdatas = [google_compute_global_address.nomad_consul.address]
}

resource "google_dns_record_set" "ingress" {
  count = var.dns_zone != "" ? 1 : 0
  name  = "ingress.${var.cluster_name}.${data.google_dns_managed_zone.doormat_dns_zone[0].dns_name}"
  type  = "A"
  ttl   = 300

  managed_zone = data.google_dns_managed_zone.doormat_dns_zone[0].name

  rrdatas = [google_compute_forwarding_rule.clients-lb[0].ip_address]
}

resource "google_dns_record_set" "ingress_cname" {
  count = var.dns_zone != "" ? 1 : 0
  name  = "*.ingress.${var.cluster_name}.${data.google_dns_managed_zone.doormat_dns_zone[0].dns_name}"
  type  = "CNAME"
  ttl   = 300

  managed_zone = data.google_dns_managed_zone.doormat_dns_zone[0].name

  rrdatas = ["ingress.${var.cluster_name}.${data.google_dns_managed_zone.doormat_dns_zone[0].dns_name}"]
}
