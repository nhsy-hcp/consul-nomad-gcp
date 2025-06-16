# Template to build a GCP client image with Consul, Nomad and Vault installed

source "googlecompute" "consul_nomad_client_gpu" {
  project_id = var.gcp_project
  source_image_family = var.source_image_family
  image_name = "consul-nomad-ent-${local.consul_version}-${local.nomad_version}-client-gpu"
  image_family = "${var.image_family}-client-gpu"
  machine_type = "n1-standard-1"
  accelerator_type = "projects/${var.gcp_project}/zones/${var.gcp_zone}/acceleratorTypes/nvidia-tesla-t4"
  accelerator_count = 1
  on_host_maintenance = "TERMINATE"
  disk_size = 50
  ssh_username = var.sshuser
  zone = var.gcp_zone
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
  sources = ["sources.googlecompute.consul_nomad_client_gpu"]
  provisioner "shell" {
    scripts = ["../consul_prep.sh","../nomad_prep.sh"]
    # execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo '{{ .Path }}'"
    environment_vars = [
      "CONSUL_VERSION=${var.consul_version}",
      "NOMAD_VERSION=${var.nomad_version}",
      "VAULT_VERSION=${var.vault_version}"
    ]
  }
  provisioner "shell" {
    scripts = ["../client_gpu_prep1.sh"]
    # expect_disconnect = true
  }
  provisioner "shell" {
    inline = ["sudo reboot -f"]
    expect_disconnect = true
  }
  provisioner "shell" {
    scripts = ["../client_gpu_prep2.sh"]
  }
}