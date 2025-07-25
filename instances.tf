# Creating Nomad Bootstrap token
resource "random_uuid" "nomad_bootstrap" {
}

# Let's get the zones from the region
data "google_compute_zones" "available" {
  region = var.gcp_region
}
# data "google_compute_zones" "available" {}


# Creating the instance template to be use from instances
resource "google_compute_instance_template" "instance_template" {
  # count = var.numnodes
  name_prefix  = "${var.cluster_name}-servers-"
  machine_type = var.gcp_instance
  region       = var.gcp_region

  tags = [var.cluster_name, var.owner, "nomad-${var.cluster_name}"]

  // boot disk
  disk {
    source_image = local.vm_image
    device_name  = "consul-${var.cluster_name}"
    # source = google_compute_region_disk.vault_disk.name
  }
  network_interface {
    subnetwork = google_compute_subnetwork.subnet.self_link

    access_config {
      # nat_ip = google_compute_address.server_addr.address
    }
  }
  service_account {
    email  = google_service_account.compute.email
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_template" "nomad_clients" {
  # Let's create a count, so we create a template for each consul partition, and use only one if consul_partitions is empty
  count = length(var.consul_partitions) != 0 ? length(var.consul_partitions) : 1

  name_prefix  = "${var.cluster_name}-clients-${length(var.consul_partitions) != 0 ? var.consul_partitions[count.index] : "default"}-"
  machine_type = var.nomad_client_machine_type
  region       = var.gcp_region

  tags = [var.cluster_name, var.owner, "nomad-${var.cluster_name}"]

  // boot disk
  disk {
    source_image = local.client_vm_image
    # source_image = local.vm_image
    device_name = "consul-${var.cluster_name}"
    # source = google_compute_region_disk.vault_disk.name
    disk_size_gb = var.nomad_client_disk_size
  }
  scheduling {
    preemptible       = var.nomad_client_preemptible
    automatic_restart = var.nomad_client_preemptible ? false : true
  }
  network_interface {
    subnetwork = google_compute_subnetwork.subnet.self_link

    access_config {
      # nat_ip = google_compute_address.server_addr.address
    }
  }
  service_account {
    email  = google_service_account.compute.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = templatefile("${path.module}/template/template-client.tpl", {
    dc_name            = var.cluster_name,
    gcp_project        = var.gcp_project,
    tag                = var.cluster_name,
    consul_license     = var.consul_license,
    nomad_license      = var.nomad_license,
    bootstrap_token    = var.consul_bootstrap_token,
    consul_encrypt_key = random_bytes.consul_encrypt_key.base64,
    zone               = var.gcp_region,
    node_name          = "clients-${count.index}",
    partition          = var.consul_partitions != [""] ? element(local.admin_partitions, count.index) : "default"
  })
  labels = {
    node = "client-${count.index}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_template" "nomad_gpu_clients" {
  # Let's create a count, so we create a template for each consul partition, and use only one if consul_partitions is empty
  count = length(var.consul_partitions) != 0 ? length(var.consul_partitions) : 1

  name_prefix  = "${var.cluster_name}-clients-gpu-${length(var.consul_partitions) != 0 ? var.consul_partitions[count.index] : "default"}-"
  machine_type = var.nomad_client_machine_type
  region       = var.gcp_region

  tags = [var.cluster_name, var.owner, "nomad-${var.cluster_name}"]

  // boot disk
  disk {
    source_image = local.client_vm_image
    # source_image = local.vm_image
    device_name = "consul-${var.cluster_name}"
    # source = google_compute_region_disk.vault_disk.name
    disk_size_gb = var.nomad_client_disk_size
  }
  scheduling {
    on_host_maintenance = "TERMINATE"
    automatic_restart   = false
  }
  guest_accelerator {
    type  = "nvidia-tesla-t4"
    count = 1
  }
  network_interface {
    subnetwork = google_compute_subnetwork.subnet.self_link

    access_config {
      # nat_ip = google_compute_address.server_addr.address
    }
  }
  service_account {
    email  = google_service_account.compute.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = templatefile("${path.module}/template/template-client-gpu.tpl", {
    dc_name            = var.cluster_name,
    gcp_project        = var.gcp_project,
    tag                = var.cluster_name,
    consul_license     = var.consul_license,
    nomad_license      = var.nomad_license,
    bootstrap_token    = var.consul_bootstrap_token,
    consul_encrypt_key = random_bytes.consul_encrypt_key.base64,
    zone               = var.gcp_region,
    node_name          = "client-gpu-${count.index}",
    partition          = var.consul_partitions != [""] ? element(local.admin_partitions, count.index) : "default"
  })
  labels = {
    node = "client-gpu-${count.index}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# This is the instance template for a node that will be used for Consul Terraform Sync if we deploy it
resource "google_compute_instance_from_template" "vm_cts" {
  count = var.enable_cts ? 1 : 0

  name = "${var.cluster_name}-cts-${local.unique_id}"
  # zone = var.gcp_zone
  zone = element(var.gcp_zones, count.index)

  source_instance_template = google_compute_instance_template.nomad_clients[0].id

  // Override fields from instance template
  network_interface {
    subnetwork = google_compute_subnetwork.subnet.self_link
    access_config {}
  }

  # The template used is just an own demo example that won't work by default, but it is just to show how to use the template
  metadata_startup_script = templatefile("${path.module}/template/template-cts.tpl", {
    dc_name            = var.cluster_name,
    gcp_project        = var.gcp_project,
    tag                = var.cluster_name,
    consul_license     = var.consul_license,
    bootstrap_token    = var.consul_bootstrap_token,
    consul_encrypt_key = random_bytes.consul_encrypt_key.base64,
    node_name          = "client-cts",
    tfc_token          = var.tfc_token,
    zone               = var.gcp_region
  })

  labels = {
    node = "client-cts"
  }
  # lifecycle {
  #   create_before_destroy = true
  # }
}


# Create the instance group from the vms in a region
# Create instance group for the region
resource "google_compute_region_instance_group_manager" "hashi-group" {
  depends_on = [
    google_compute_instance_template.instance_template
  ]
  name = "${var.cluster_name}-server-mig"

  base_instance_name        = "hashi-server"
  region                    = var.gcp_region
  distribution_policy_zones = slice(data.google_compute_zones.available.names, 0, 3)

  version {
    instance_template = google_compute_instance_template.instance_template.self_link
  }

  all_instances_config {
    metadata = {
      component = "server"
    }
    labels = {
      mesh      = "consul"
      scheduler = "nomad"
    }
  }

  stateful_disk {
    device_name = "consul-${var.cluster_name}"
    delete_rule = "ON_PERMANENT_INSTANCE_DELETION"
  }

  update_policy {
    type = "OPPORTUNISTIC"
    # type = "PROACTIVE"
    minimal_action               = "REPLACE"
    instance_redistribution_type = "NONE"
    # replacement_method           = "RECREATE"
    max_surge_fixed = 0
    # Fixed updatePolicy.maxUnavailable for regional managed instance group has to be either 0 or at least equal to the number of zones in the region.
    max_unavailable_fixed = max(length(data.google_compute_zones.available.names), floor(var.server_nodes / 2))
  }


  # target_pools = [google_compute_target_pool.appserver.id]
  # target_size  = var.numnodes

  named_port {
    name = "consul"
    port = 8500
  }
  named_port {
    name = "consul-https"
    port = 8501
  }
  named_port {
    name = "consul-grpc"
    port = 8502
  }
  named_port {
    name = "consul-lan"
    port = 8301
  }
  named_port {
    name = "consul-wan"
    port = 8302
  }
  named_port {
    name = "consul-server"
    port = 8300
  }
  named_port {
    name = "nomad-https"
    port = 4646
  }
  named_port {
    name = "nomad-rpc"
    port = 4647
  }
  named_port {
    name = "nomad-wan"
    port = 4648
  }
}


# We do a stateful address for the instances, so the execution script on each instance is not the same
resource "google_compute_region_per_instance_config" "with_script" {
  count = var.server_nodes

  region                        = google_compute_region_instance_group_manager.hashi-group.region
  region_instance_group_manager = google_compute_region_instance_group_manager.hashi-group.name
  name                          = "${var.cluster_name}-server-${count.index}-${local.unique_id}"
  preserved_state {
    # internal_ip {
    #   interface_name = "nic0"
    #   ip_address {
    #     address = google_compute_address.server_addr[count.index].id
    #   }
    # }
    metadata = {
      startup-script = templatefile("${path.module}/template/template.tpl", {
        dc_name            = var.cluster_name,
        gcp_project        = var.gcp_project,
        tag                = var.cluster_name,
        consul_license     = var.consul_license,
        nomad_license      = var.nomad_license,
        zone               = var.gcp_region,
        bootstrap_token    = var.consul_bootstrap_token,
        consul_encrypt_key = random_bytes.consul_encrypt_key.base64,
        node_name          = "${var.cluster_name}-server-${count.index}",
        nomad_token        = random_uuid.nomad_bootstrap.result,
        nomad_bootstrapper = count.index == var.server_nodes - 1 ? true : false,
        oidc_issuer        = local.nomad_https_url
      })
      instance_template = google_compute_instance_template.instance_template.self_link
    }
  }
}



# Creating an instance group region for the clients
resource "google_compute_region_instance_group_manager" "clients-group" {
  # We create an instance group for the clients, so we can use the same instance template for all the instances. And we create a groupt per partition.
  depends_on = [
    google_compute_instance_template.nomad_clients
  ]
  count                     = length(var.consul_partitions) != 0 ? length(var.consul_partitions) : 1
  name                      = "${var.cluster_name}-clients-mig-${count.index}"
  base_instance_name        = length(var.consul_partitions) != 0 ? "${var.cluster_name}-clients-${var.consul_partitions[count.index]}" : "${var.cluster_name}-clients"
  region                    = var.gcp_region
  distribution_policy_zones = slice(data.google_compute_zones.available.names, 0, 3)

  version {
    instance_template = google_compute_instance_template.nomad_clients[count.index].self_link
  }

  all_instances_config {
    metadata = {
      component = "client"
    }
    labels = {
      mesh      = "consul"
      scheduler = "nomad"
    }
  }

  update_policy {
    # type  = "OPPORTUNISTIC"
    type                         = "PROACTIVE"
    minimal_action               = "REPLACE"
    instance_redistribution_type = "NONE"
    # max_surge_fixed = 0
    # # Fixed updatePolicy.maxUnavailable for regional managed instance group has to be either 0 or at least equal to the number of zones in the region.
    # max_unavailable_fixed = max(length(data.google_compute_zones.available.names),floor(var.numclients / 2))
    max_surge_fixed       = length(data.google_compute_zones.available.names)
    max_unavailable_fixed = 0
  }

  target_size = var.nomad_clients
  named_port {
    name = "http-80"
    port = 80
  }
  named_port {
    name = "http-8080"
    port = 8080
  }
  named_port {
    name = "https"
    port = 443
  }
  named_port {
    name = "https-8443"
    port = 8443
  }
}

# Creating an instance group region for the clients
resource "google_compute_region_instance_group_manager" "nomad_gpu_clients" {
  # We create an instance group for the clients, so we can use the same instance template for all the instances. And we create a groupt per partition.
  depends_on = [
    google_compute_instance_template.nomad_gpu_clients
  ]
  count                     = length(var.consul_partitions) != 0 ? length(var.consul_partitions) : 1
  name                      = "${var.cluster_name}-clients-gpu-mig-${count.index}"
  base_instance_name        = length(var.consul_partitions) != 0 ? "${var.cluster_name}-clients-gpu-${var.consul_partitions[count.index]}" : "${var.cluster_name}-clients-gpu"
  region                    = var.gcp_region
  distribution_policy_zones = slice(data.google_compute_zones.available.names, 0, 3)

  version {
    instance_template = google_compute_instance_template.nomad_gpu_clients[count.index].self_link
  }

  all_instances_config {
    metadata = {
      component = "client"
    }
    labels = {
      mesh      = "consul"
      scheduler = "nomad"
    }
  }

  update_policy {
    # type  = "OPPORTUNISTIC"
    type                         = "PROACTIVE"
    minimal_action               = "REPLACE"
    instance_redistribution_type = "NONE"
    # max_surge_fixed = 0
    # # Fixed updatePolicy.maxUnavailable for regional managed instance group has to be either 0 or at least equal to the number of zones in the region.
    # max_unavailable_fixed = max(length(data.google_compute_zones.available.names),floor(var.numclients / 2))
    max_surge_fixed       = length(data.google_compute_zones.available.names)
    max_unavailable_fixed = 0
  }

  target_size = var.nomad_gpu_clients
}
