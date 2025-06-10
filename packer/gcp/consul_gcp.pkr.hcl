variable "gcp_project" {
  description = "GCP Project"
}
variable "sshuser" {
  description = "Username for SSH"
}
variable "gcp_zone" {
  description = "GCP Zone"
  default = "europe-west1-c"
}
variable "image" {
  default = "consul-nomad"
}
variable "consul_version" {
  default = "1.12.1"
}
variable "nomad_version" {
  default = "1.5.1"
}
variable "vault_version" {
  default = "1.14.1"
}
variable "image_family" {
  default = "hashistack"
}
variable "source_image_family" {
  default = "debian-11"
}
variable "hcp_bucket_name" {
  description = "HCP Bucket Name"
  default = "consul-nomad"
}

locals {
  consul_version = regex_replace(var.consul_version,"\\.+|\\+","-")
  nomad_version = regex_replace(var.nomad_version,"\\.+|\\+","-")
}


source "googlecompute" "consul_nomad" {
  project_id = var.gcp_project
  source_image_family = var.source_image_family
  image_name = "${var.image}-${local.consul_version}-${local.nomad_version}"
  image_family = var.image_family
  machine_type = "n2-standard-2"
  # disk_size = 50
  ssh_username = var.sshuser
  zone = var.gcp_zone
  # image_licenses = ["projects/vm-options/global/licenses/enable-vmx"]
}

build {
#   hcp_packer_registry {
#     bucket_name = var.hcp_bucket_name
#     description = <<EOT
# Image for Consul, Nomad and Vault
#     EOT
#     bucket_labels = {
#       "hashicorp"    = "Vault,Consul,Nomad",
#       "owner" = "dcanadillas",
#       "platform" = "hashicorp",
#     }
#   }
  sources = ["sources.googlecompute.consul_nomad"]
  provisioner "shell" {
    scripts = ["../consul_prep.sh","../nomad_prep.sh"]
    # execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo '{{ .Path }}'"
    environment_vars = [
      "CONSUL_VERSION=${var.consul_version}",
      "NOMAD_VERSION=${var.nomad_version}",
      "VAULT_VERSION=${var.vault_version}"
    ]
  }
}