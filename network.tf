## ----- Network capabilities ------
# VPC creation
resource "google_compute_network" "network" {
  name                    = "${var.cluster_name}-network"
  auto_create_subnetworks = false
}

#Subnet creation
resource "google_compute_subnetwork" "subnet" {
  name = "${var.cluster_name}-subnetwork"

  ip_cidr_range = var.subnetwork_cidr
  region        = var.gcp_region
  network       = google_compute_network.network.id
}



# Create firewall rules

resource "google_compute_firewall" "default" {
  name    = "${var.cluster_name}-fw-${local.unique_id}"
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
  name    = "${var.cluster_name}-internal-fw-${local.unique_id}"
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
    balancing_mode = "CONNECTION"
    group          = google_compute_region_instance_group_manager.clients-group[count.index].instance_group
  }
}


resource "google_compute_region_health_check" "apps" {
  name               = "${var.cluster_name}-health-check-apigw"
  check_interval_sec = 1
  timeout_sec        = 1
  region             = var.gcp_region

  tcp_health_check {
    port = "80"
  }
}

resource "google_compute_health_check" "nomad" {
  name                = "${var.cluster_name}-nomad-health-check"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 3
  unhealthy_threshold = 5
  http_health_check {
    port         = 4646
    port_name    = "nomad-https"
    request_path = "/v1/agent/health"
  }
  log_config {
    enable = false
  }
}

resource "google_compute_backend_service" "nomad" {
  name                  = "${var.cluster_name}-nomad-backend-service"
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 300
  health_checks         = [google_compute_health_check.nomad.id]
  port_name             = "nomad-https"

  log_config {
    enable      = false
    sample_rate = 1.0
  }

  backend {
    group           = google_compute_region_instance_group_manager.hashi-group.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_health_check" "consul" {
  name                = "${var.cluster_name}-consul-health-check"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 3
  unhealthy_threshold = 5
  https_health_check {
    port         = 8501
    port_name    = "consul-https"
    request_path = "/v1/status/leader"
  }
  log_config {
    enable = false
  }
}

resource "google_compute_backend_service" "consul" {
  name                  = "${var.cluster_name}-consul-backend-service"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 300
  health_checks         = [google_compute_health_check.consul.id]
  port_name             = "consul-https"

  log_config {
    enable      = false
    sample_rate = 1.0
  }

  backend {
    group           = google_compute_region_instance_group_manager.hashi-group.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

# Create a global application load balancer with google managed TLS certificate for nomad and consul
resource "google_compute_global_address" "nomad_consul" {
  name = "${var.cluster_name}-global-ip"
}

resource "google_compute_url_map" "nomad" {
  # provider        = google-beta
  default_service = google_compute_backend_service.nomad.self_link
  name            = "${var.cluster_name}-nomad-url-map"
}

resource "google_compute_target_https_proxy" "nomad" {
  # provider         = google-beta
  name = "${var.cluster_name}-https-proxy"
  # ssl_certificates = [google_compute_managed_ssl_certificate.nomad_consul.self_link]
  ssl_certificates = [google_compute_ssl_certificate.nomad_consul.self_link]
  url_map          = google_compute_url_map.nomad.self_link
}

resource "google_compute_global_forwarding_rule" "nomad" {
  # provider              = google-beta
  name                  = "${var.cluster_name}-forwarding-rule"
  ip_address            = google_compute_global_address.nomad_consul.address
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "4646"
  target                = google_compute_target_https_proxy.nomad.self_link
}

# Create Consul L7 Load Balancer components
# Note: Using shared global address with Nomad

resource "google_compute_url_map" "consul" {
  default_service = google_compute_backend_service.consul.self_link
  name            = "${var.cluster_name}-consul-url-map"
}

resource "google_compute_target_https_proxy" "consul" {
  name = "${var.cluster_name}-consul-https-proxy"
  # ssl_certificates = [google_compute_managed_ssl_certificate.nomad_consul.self_link]
  ssl_certificates = [google_compute_ssl_certificate.nomad_consul.self_link]
  url_map          = google_compute_url_map.consul.self_link
}

resource "google_compute_global_forwarding_rule" "consul" {
  name                  = "${var.cluster_name}-consul-forwarding-rule"
  ip_address            = google_compute_global_address.nomad_consul.address
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "8501"
  target                = google_compute_target_https_proxy.consul.self_link
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
