locals {
  # unique_id = random_id.default.hex
  unique_id = random_pet.unique_id.id

  # We concatenate the default partition with the list of partitions to create the instances including the default partition
  admin_partitions = distinct(concat(["default"], var.consul_partitions))
  # vm_image         = var.use_hcp_packer ? data.hcp_packer_artifact.consul-nomad[0].external_identifier : data.google_compute_image.my_image.self_link
  vm_image = data.google_compute_image.my_image.self_link

  fqdn        = trimsuffix("${var.cluster_name}.${data.google_dns_managed_zone.doormat_dns_zone[0].dns_name}", ".")
  consul_fqdn = trimsuffix(google_dns_record_set.consul[0].name, ".")
  nomad_fqdn  = trimsuffix(google_dns_record_set.nomad[0].name, ".")

  client_vm_image = data.google_compute_image.client_image.self_link

  nomad_https_url  = "https://${local.nomad_fqdn}:4646"
  consul_https_url = "https://${local.consul_fqdn}:8501"
}

resource "random_pet" "unique_id" {
  length    = 1
  separator = ""
}

data "google_client_config" "current" {}

data "google_compute_image" "my_image" {
  family  = var.image_family
  project = var.gcp_project
}

data "google_compute_image" "client_image" {
  family  = "${var.image_family}-client-gpu"
  project = var.gcp_project
}

# # Let's take the image from HCP Packer
# data "hcp_packer_version" "hardened-source" {
#   count        = var.use_hcp_packer ? 1 : 0
#   bucket_name  = var.hcp_packer_bucket
#   channel_name = var.hcp_packer_channel
# }
#
# data "hcp_packer_artifact" "consul-nomad" {
#   count               = var.use_hcp_packer ? 1 : 0
#   bucket_name         = var.hcp_packer_bucket
#   version_fingerprint = data.hcp_packer_version.hardened-source[0].fingerprint
#   platform            = "gce"
#   region              = var.hcp_packer_region
# }

resource "random_bytes" "consul_encrypt_key" {
  length = 32
}
