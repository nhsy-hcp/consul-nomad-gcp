terraform {
  required_version = ">= 1.0.0"
  # backend "remote" {
  # }
}

resource "random_id" "server" {
  byte_length = 1
}

# Collect client config for GCP
data "google_client_config" "current" {
}
data "google_service_account" "owner_project" {
  account_id = var.gcp_sa
}



## ----- Network capabilities ------
# VPC creation
resource "google_compute_network" "network" {
  name = "${var.cluster_name}-network"
}


# Subnet creation
resource "google_compute_subnetwork" "subnet" {
  name = "${var.cluster_name}-subnetwork"

  ip_cidr_range = "10.2.0.0/16"
  region        = var.gcp_region
  network       = google_compute_network.network.id
}

# Create an ip address for the load balancer
resource "google_compute_address" "global-ip" {
  name = "lb-ip"
  region = var.gcp_region
}

# External IP addresses
resource "google_compute_address" "server_addr" {
  count = var.numnodes
  name  = "server-addr-${count.index}"
  # subnetwork = google_compute_subnetwork.subnet.id
  region = var.gcp_region
}

resource "google_compute_address" "client_addr" {
  count = var.numclients
  name  = "client-addr-${count.index}"
  # subnetwork = google_compute_subnetwork.subnet.id
  region = var.gcp_region
}

# Create firewall rules

resource "google_compute_firewall" "default" {
  name    = "hashi-rules"
  network = google_compute_network.network.name

  allow {
    protocol = "tcp"
    ports    = ["80","443","8500","8501","8502","8503","22","8300","8301","8400","8302","8600","4646","4647","4648","8443"]
  }
  allow {
    protocol = "udp"
    ports = ["8600","8301","8302"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.cluster_name,"nomad-${var.cluster_name}","consul-${var.cluster_name}"]
}
# These are internal rules for communication between the nodes internally
resource "google_compute_firewall" "internal" {
  name    = "hashi-internal-rules"
  network = google_compute_network.network.name

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }

  source_tags = [var.cluster_name,"nomad-${var.cluster_name}","consul-${var.cluster_name}"]
  target_tags   = [var.cluster_name,"nomad-${var.cluster_name}","consul-${var.cluster_name}"]
}     

# Creating Load Balancing with different required resources
resource "google_compute_region_backend_service" "default" {
  name          = "${var.cluster_name}-backend-service"
  health_checks = [
    google_compute_region_health_check.default.id
  ]
  region = var.gcp_region
  protocol = "TCP"
  load_balancing_scheme = "EXTERNAL"
  backend {
    group  = google_compute_instance_group.hashi_group.id
    # balancing_mode = "CONNECTION"
  }
}

resource "google_compute_region_backend_service" "hashicups" {
  name          = "${var.cluster_name}-hashicups"
  health_checks = [
    google_compute_region_health_check.default.id
  ]
  region = var.gcp_region
  protocol = "TCP"
  load_balancing_scheme = "EXTERNAL"
  backend {
    group  = google_compute_instance_group.hashi_group.id
    # balancing_mode = "CONNECTION"
  }
}

# resource "google_compute_target_pool" "vm-pool" {
#   name = "instance-pool"

#   instances = google_compute_instance_from_template.tpl-vm.*.name

#   health_checks = [
#     google_compute_http_health_check.default.name,
#   ]
# }

resource "google_compute_region_health_check" "default" {
  name = "health-check"
  # request_path       = "/"
  check_interval_sec = 1
  timeout_sec        = 1
  region = var.gcp_region

  http_health_check {
    port = "8500"
    request_path = "/ui"
  }
}

resource "google_compute_region_health_check" "hashicups" {
  name = "health-check-hashicups"
  check_interval_sec = 1
  timeout_sec        = 1
  region = var.gcp_region

  http_health_check {
    port = "80"
    request_path = "/"
  }
}

resource "google_compute_forwarding_rule" "global-lb" {
  name       = "hashistack-lb"
  # ip_address = google_compute_global_address.global-ip.address
  ip_address = google_compute_address.global-ip.address
  # target     = google_compute_target_pool.vm-pool.self_link
  backend_service = google_compute_region_backend_service.default.id
  region = var.gcp_region
  ip_protocol = "TCP"
  ports = ["4646-4648","8500-8503","8600","9701-9702","8443"]
}

resource "google_compute_forwarding_rule" "clients-lb" {
  name       = "clients-lb"
  #  ip_address = google_compute_address.global-ip.address
  backend_service = google_compute_region_backend_service.hashicups.id
  region = var.gcp_region
  ip_protocol = "TCP"
  ports = ["80","443","8443","8080"]
}





data "google_compute_image" "my_image" {
  family  = var.image_family
  project = var.gcp_project
}

data "google_dns_managed_zone" "doormat_dns_zone" {
  name = var.dns_zone
}

resource "google_dns_record_set" "dns" {
  name = "hashi.${data.google_dns_managed_zone.doormat_dns_zone.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.doormat_dns_zone.name

  rrdatas = [google_compute_forwarding_rule.global-lb.ip_address]
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