# resource "null_resource" "nomad_wait_for_service" {
#   depends_on = [
#     google_compute_region_instance_group_manager.hashi-group,
#     google_compute_region_per_instance_config.with_script
#   ]
#   provisioner "local-exec" {
#     command = <<EOF
# until $(curl -k --output /dev/null --silent --head --fail https://${trimsuffix(local.fqdn, ".")}:4646); do
#   printf '...'
#   sleep 5
# done
# nomad setup consul -y --address=https://${trimsuffix(local.fqdn, ".")}:4646 --token=${random_uuid.nomad_bootstrap.result}
# EOF
#   }
# }