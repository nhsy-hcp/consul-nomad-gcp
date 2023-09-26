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
  default = "1.12.0"
}
variable "nomad_version" {
  default = "1.3.1"
}
variable "image_family" {
  default = "hashistack"
}

locals {
  consul_version = regex_replace(var.consul_version,"\\.+|\\+","-")
  nomad_version = regex_replace(var.nomad_version,"\\.+|\\+","-")
}


source "googlecompute" "consul_nomad" {
  project_id = var.gcp_project
  source_image_family = "debian-10"
  image_name = "${var.image}-${local.consul_version}-${local.nomad_version}"
  image_family = var.image_family
  machine_type = "n2-standard-2"
  # disk_size = 50
  ssh_username = var.sshuser
  zone = var.gcp_zone
  # image_licenses = ["projects/vm-options/global/licenses/enable-vmx"]
}


build {
  sources = ["sources.googlecompute.consul_nomad"]
  provisioner "shell" {
    scripts = ["../consul_prep.sh","../nomad_prep.sh"]
    # execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo '{{ .Path }}'"
    environment_vars = [
      "CONSUL_VERSION=${var.consul_version}",
      "NOMAD_VERSION=${var.nomad_version}"
    ]
  }
}