variable "gcp_region" {
  description = "Google Cloud region"
  type        = string
  default     = "europe-west1"
}
# variable "gcp_zone" {
#   description = "Google Cloud region"
#   validation {
#     # Validating that zone is within the region
#     condition     = var.gcp_zone == regex("[a-z]+-[a-z]+[0-1]-[abc]",var.gcp_zone)
#     error_message = "The GCP zone ${var.gcp_zone} needs to be a valid one."
#   }

# }
variable "gcp_zones" {
  description = "Zones to spread the clients. This is a list of zones"
  type        = list(string)
  default     = ["europe-west1-c"]
  # Let's do a validation to check that the zones are within the region
  validation {
    condition     = alltrue([for zone in var.gcp_zones : contains(regexall("[a-z]+-[a-z]+[0-1]-[a-z]", zone), zone)])
    error_message = "The GCP zones ${join(",", var.gcp_zones)} needs to be a valid one."
  }
}
variable "gcp_project" {
  description = "Cloud project"
  type        = string
}
variable "gcp_instance" {
  description = "Machine type for nodes"
  type        = string
}
# variable "gcp_zones" {
#   description = "availability zones"
#   type = list(string)
# }
variable "server_nodes" {
  description = "number of server nodes"
  type        = number
  default     = 3
}
variable "nomad_clients" {
  description = "number of client nodes"
  type        = number
  default     = 2
}
variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
}
variable "owner" {
  description = "Owner of the cluster"
  type        = string
}
variable "consul_license" {
  description = "Consul Enterprise license text"
  type        = string
}
variable "nomad_license" {
  description = "Nomad Enterprise license text"
  type        = string
}
variable "tfc_token" {
  description = "Terraform Cloud token to use for CTS"
  type        = string
  default     = ""
}

variable "consul_bootstrap_token" {
  description = "Terraform Cloud token to use for CTS"
  type        = string
}

variable "image_family" {
  description = "Image family to use for compute instances"
  type        = string
  default     = "hashistack"
}

variable "dns_zone" {
  description = "An already existing DNS zone in your GCP project"
  type        = string
  default     = null
}

variable "consul_partitions" {
  description = "List of Consul Admin Partitions"
  type        = list(string)
  default     = []
}

variable "hcp_project_id" {
  description = "HCP Project ID"
  type        = string
}

variable "enable_cts" {
  description = "Set it to true to deploy a node for CTS"
  type        = string
  default     = "false"
}

variable "subnetwork_cidr" {
  description = "CIDR for the subnetwork"
  type        = string
  default     = "10.2.0.0/16"
}

variable "nomad_client_disk_size" {
  description = "Disk size for Nomad nodes"
  type        = number
  default     = 100
}

variable "nomad_client_machine_type" {
  description = "Machine type for nodes"
  type        = string
  default     = "n1-standard-4"
}

variable "nomad_client_preemptible" {
  description = "Use preemptible VMs for Nomad clients"
  type        = bool
  default     = false
}

variable "nomad_gpu_clients" {
  description = "number of gpu client nodes"
  type        = number
  default     = 0
}

variable "compute_sa_roles" {
  description = "IAM roles to assign to the compute service account"
  type        = set(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/compute.networkViewer",
    "roles/storage.objectViewer",
  ]
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt"
  type        = string
}

variable "cni_plugin_version" {
  description = "Version of CNI plugins to install"
  type        = string
  default     = "v1.9.0"
}

variable "consul_cni_version" {
  description = "Version of Consul CNI plugin to install"
  type        = string
  default     = "1.9.5"
}

variable "consul_log_level" {
  description = "Log level for Consul agents (TRACE, DEBUG, INFO, WARN, ERR)"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["TRACE", "DEBUG", "INFO", "WARN", "ERR"], var.consul_log_level)
    error_message = "Consul log level must be one of: TRACE, DEBUG, INFO, WARN, ERR"
  }
}
