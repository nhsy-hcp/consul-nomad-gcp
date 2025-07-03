terraform {
  required_version = ">= 1.0.0"
  # backend "remote" {
  # }
}

resource "random_id" "default" {
  byte_length = 1
}

# Collect client config for GCP
data "google_service_account" "owner_project" {
  account_id = var.gcp_sa
}

## ----- Network capabilities ------
# VPC creation
resource "google_compute_network" "network" {
  name = "${var.cluster_name}-network"
    auto_create_subnetworks = false
}

#Subnet creation
resource "google_compute_subnetwork" "subnet" {
  name = "${var.cluster_name}-subnetwork"

  ip_cidr_range = var.subnetwork_cidr
  region        = var.gcp_region
  network       = google_compute_network.network.id
}

# Create an ip address for the load balancer
resource "google_compute_address" "global-ip" {
  name   = "${var.cluster_name}-lb-ip"
  region = var.gcp_region
}

# External IP addresses
resource "google_compute_address" "server_addr" {
  count = var.server_nodes
  name  = "${var.cluster_name}-server-addr-${count.index}"
  # subnetwork = google_compute_subnetwork.subnet.id
  region = var.gcp_region
}

resource "google_compute_address" "client_addr" {
  count = var.nomad_clients
  name  = "${var.cluster_name}-client-addr-${count.index}"
  # subnetwork = google_compute_subnetwork.subnet.id
  region = var.gcp_region
}

# Create firewall rules

resource "google_compute_firewall" "default" {
  name    = "${var.cluster_name}-fw-${random_id.default.dec}"
  network = google_compute_network.network.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8500", "8501", "8502", "8503", "22", "8300", "8301", "8400", "8302", "8600", "4646", "4647", "4648", "8443", "8080"]
  }
  allow {
    protocol = "udp"
    ports    = ["8600", "8301", "8302"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.cluster_name, "nomad-${var.cluster_name}", "consul-${var.cluster_name}"]
}
# These are internal rules for communication between the nodes internally
resource "google_compute_firewall" "internal" {
  name    = "${var.cluster_name}-internal-fw-${random_id.default.dec}"
  network = google_compute_network.network.name

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }

  source_tags = [var.cluster_name, "nomad-${var.cluster_name}", "consul-${var.cluster_name}"]
  target_tags = [var.cluster_name, "nomad-${var.cluster_name}", "consul-${var.cluster_name}"]
}

# Creating Load Balancing with different required resources
resource "google_compute_region_backend_service" "default" {
  name = "${var.cluster_name}-backend-service"
  health_checks = [
    google_compute_region_health_check.default.id
  ]
  region                = var.gcp_region
  protocol              = "TCP"
  load_balancing_scheme = "EXTERNAL"
  backend {
    # group  = google_compute_instance_group.hashi_group.id
    group = google_compute_region_instance_group_manager.hashi-group.instance_group
    # balancing_mode = "CONNECTION"
  }
}

resource "google_compute_region_backend_service" "apps" {
  count = length(google_compute_region_instance_group_manager.clients-group)
  name  = "${var.cluster_name}-apigw-${count.index}"
  health_checks = [
    google_compute_region_health_check.apps.id
  ]
  region                = var.gcp_region
  protocol              = "TCP"
  load_balancing_scheme = "EXTERNAL"
  backend {
    # group  = google_compute_instance_group.app_group.id
    group = google_compute_region_instance_group_manager.clients-group[count.index].instance_group
    # balancing_mode = "CONNECTION"
  }
}

# resource "google_compute_target_pool" "vm-pool" {
#   name = "instance-pool"

#   instances = google_compute_instance_from_template.vm_clients.*.self_link

#   health_checks = [
#     google_compute_http_health_check.apps.id,
#   ]
# }

resource "google_compute_region_health_check" "default" {
  name = "${var.cluster_name}-health-check"
  # request_path       = "/"
  check_interval_sec = 1
  timeout_sec        = 1
  region             = var.gcp_region

  # http_health_check {
  #   port = "8500"
  #   request_path = "/ui"
  # }
  tcp_health_check {
    port = "8500"
  }
}

resource "google_compute_region_health_check" "apps" {
  name               = "${var.cluster_name}-health-check-apigw"
  check_interval_sec = 1
  timeout_sec        = 1
  region             = var.gcp_region

  # http_health_check {
  #   port = "8080"
  #   request_path = "/"
  # }
  tcp_health_check {
    port = "80"
  }
}
# resource "google_compute_http_health_check" "apps" {
#   name               = "default"
#   request_path       = "/"
#   check_interval_sec = 1
#   timeout_sec        = 1
#   port = 8080
# }

resource "google_compute_forwarding_rule" "global-lb" {
  name = "${var.cluster_name}-lb"
  # ip_address = google_compute_global_address.global-ip.address
  ip_address = google_compute_address.global-ip.address
  # target     = google_compute_target_pool.vm-pool.self_link
  backend_service = google_compute_region_backend_service.default.id
  region          = var.gcp_region
  ip_protocol     = "TCP"
  ports           = ["4646-4648", "8500-8503", "8600", "9701-9702", "8443"]
}

# The number of LBs for the apps will be equal to the number of region instance groups (one per admin partition)
resource "google_compute_forwarding_rule" "clients-lb" {
  count = length(google_compute_region_backend_service.apps)
  name  = "${var.cluster_name}-clients-lb"
  #  ip_address = google_compute_address.global-ip.address
  backend_service = google_compute_region_backend_service.apps[count.index].id
  # target    = google_compute_target_pool.vm-pool.self_link
  region      = var.gcp_region
  ip_protocol = "TCP"
  ports       = ["80", "443", "8443", "8080"]
}

data "google_compute_image" "my_image" {
  family  = var.image_family
  project = var.gcp_project
}

data "google_compute_image" "client_image" {
  family  = "${var.image_family}-client-gpu"
  project = var.gcp_project
}

# Let's take the image from HCP Packer
data "hcp_packer_version" "hardened-source" {
  count        = var.use_hcp_packer ? 1 : 0
  bucket_name  = var.hcp_packer_bucket
  channel_name = var.hcp_packer_channel
}

data "hcp_packer_artifact" "consul-nomad" {
  count               = var.use_hcp_packer ? 1 : 0
  bucket_name         = var.hcp_packer_bucket
  version_fingerprint = data.hcp_packer_version.hardened-source[0].fingerprint
  platform            = "gce"
  region              = var.hcp_packer_region
}


data "google_dns_managed_zone" "doormat_dns_zone" {
  count = var.dns_zone != "" ? 1 : 0
  name  = var.dns_zone
}

resource "google_dns_record_set" "dns" {
  count = var.dns_zone != "" ? 1 : 0
  name  = "${var.cluster_name}.${data.google_dns_managed_zone.doormat_dns_zone[0].dns_name}"
  type  = "A"
  ttl   = 300

  managed_zone = data.google_dns_managed_zone.doormat_dns_zone[0].name

  rrdatas = [google_compute_forwarding_rule.global-lb.ip_address]
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



# resource "google_compute_global_forwarding_rule" "hashicups" {
#   name                  = "hashicups-global-lb"
#   ip_protocol           = "TCP"
#   load_balancing_scheme = "EXTERNAL"
#   port_range            = "80"
#   target                = google_compute_target_http_proxy.hashicups.id
#   # ip_address            = google_compute_global_address.default.id
# }

# # http proxy
# resource "google_compute_target_http_proxy" "hashicups" {
#   name     = "hashicups-proxy"
#   # provider = google-beta
#   url_map  = google_compute_url_map.hashicups.id
# }

# # url map
# resource "google_compute_url_map" "hashicups" {
#   name            = "url-map-hashicups"
#   # provider        = google-beta
#   default_service = google_compute_region_backend_service.default.id
# }





# resource "google_compute_region_instance_group_manager" "appserver" {
#   name = "appserver-igm"

#   base_instance_name         = "app"
#   region                     = var.region
#   # distribution_policy_zones  = ["us-central1-a", "us-central1-f"]

#   version {
#     instance_template = google_compute_instance_template.appserver.id
#   }

#   all_instances_config {
#     metadata = {
#       metadata_key = "metadata_value"
#     }
#     labels = {
#       node = "my_node_-"
#     }
#   }

#   # target_pools = [google_compute_target_pool.appserver.id]
#   target_size  = var.numnodes

#   named_port {
#     name = "consul"
#     port = 8500
#   }
#   named_port {
#     name = "consul-sec"
#     port = 8501
#   }
#   named_port {
#     name = "consul-grpc"
#     port = 8502
#   }
#   named_port {
#     name = "consul-lan"
#     port = 8301
#   }
#   named_port {
#     name = "consul-wan"
#     port = 8302
#   }
#   named_port {
#     name = "consul-server"
#     port = 8300
#   }
#   named_port {
#     name = "nomad-server"
#     port = 4646
#   }
#   named_port {
#     name = "nomad-rpc"
#     port = 4647
#   }
#   named_port {
#     name = "nomad-wan"
#     port = 4648
#   }

#   auto_healing_policies {
#     health_check      = google_compute_health_check.autohealing.id
#     initial_delay_sec = 300
#   }
# }

# resource "google_compute_region_instance_group_manager" "rigm" {
#   name = "dc-igm"

#   base_instance_name = "consul-server"
#   region = var.gcp_region
#   distribution_policy_zones = local.zones

#   version {
#     instance_template = google_compute_instance_template.instance_template.id
#   }

#   # target_pools = [google_compute_target_pool.pool.id]
#   target_size  = var.numnodes

#   wait_for_instances = true

#   update_policy {
#     type                         = "OPPORTUNISTIC"
#     instance_redistribution_type = "NONE"
#     minimal_action               = "REPLACE"
#     max_surge_fixed = 0
#     max_unavailable_fixed = length(data.google_compute_zones.available)
#   }
#   named_port {
#     name = "consul"
#     port = 8500
#   }
#   named_port {
#     name = "consul-sec"
#     port = 8501
#   }
#   named_port {
#     name = "grpc"
#     port = 8502
#   }
#   named_port {
#     name = "lan"
#     port = 8301
#   }
#   named_port {
#     name = "wan"
#     port = 8302
#   }
#   named_port {
#     name = "server"
#     port = 8300
#   }
#   # # If want to implement autohealing for the instances in the group
#   # auto_healing_policies {
#   #   health_check      = google_compute_health_check.https_health_check.id
#   #   initial_delay_sec = 300
#   # }
#   stateful_disk {
#     device_name = "consul-${var.cluster_name}"
#   }
# }

resource "random_bytes" "consul_encrypt_key" {
  length = 32
}
