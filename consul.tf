# Let's wait for the Consul server instances to be ready before we proceed with the rest of the configuration.
resource "null_resource" "wait_for_service" {
  # depends_on = [google_compute_instance_from_template.vm_server]
  depends_on = [
    google_compute_region_instance_group_manager.hashi-group,
    google_compute_region_per_instance_config.with_script      
  ]
  provisioner "local-exec" {
    command = <<EOF
until $(curl -k --output /dev/null --silent --head --fail https://${trimsuffix(local.fqdn,".")}:8501); do
  printf '...'
  sleep 5
done
EOF
  }
}

# Create Consul Admin Partitions different than default
resource "consul_admin_partition" "demo_partitions" {
  depends_on = [ null_resource.wait_for_service ]
  count = var.consul_partitions != [] ? length(var.consul_partitions) : 0
  name        = var.consul_partitions[count.index]
  description = "Demo partition named \"${var.consul_partitions[count.index]}\""
}