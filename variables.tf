variable "gcp_region" {
  description = "Google Cloud region"
}
variable "gcp_zone" {
  description = "Google Cloud region"
  validation {
    # Validating that zone is within the region
    condition     = var.gcp_zone == regex("[a-z]+-[a-z]+[0-1]-[abc]",var.gcp_zone)
    error_message = "The GCP zone ${var.gcp_zone} needs to be a valid one."
  }

}
variable "gcp_project" {
  description = "Cloud project"
}
variable "gcp_sa" {
  description = "GCP Service Account to use for scopes"
}
variable "gcp_instance" {
  description = "Machine type for nodes"
}
# variable "gcp_zones" {
#   description = "availability zones"
#   type = list(string)
# }
variable "numnodes" {
  description = "number of server nodes"
  default = 3
}
variable "numclients" {
  description = "number of client nodes"
  default = 2
}
variable "cluster_name" {
  description = "Name of the cluster"
}
variable "owner" {
  description = "Owner of the cluster"
}
variable "server" {
  description = "Prefix for server names"
  default = "consul-server"
}
variable "consul_license" {
  description = "Consul Enterprise license text"
}
variable "nomad_license" {
  description = "Nomad Enterprise license text"
}
variable "tfc_token" {
  description = "Terraform Cloud token to use for CTS"
  default = ""
}

variable "consul_bootstrap_token" {
  description = "Terraform Cloud token to use for CTS"
  default = "ConsulR0cks!"
}

variable "image_family" {
  default = "hashistack"
}

variable "dns_zone" {
  default = "doormat-useremail"
}

variable "consul_partitions" {
  description = "List of Consul Admin Partitions"
  type = list(string)
  default = []
}

variable "use_hcp_packer" {
  description = "Use HCP Packer to store images"
  default = false
}

variable "hcp_packer_bucket" {
  description = "Bucket name for HCP Packer"
  default = "consul-nomad"  
}

variable "hcp_packer_channel" {
  description = "Channel for HCP Packer"
  default = "latest"
}

variable "hcp_packer_region" {
  description = "Region for HCP Packer"
  default = "europe-west1-c"
}
variable "hcp_project_id" {
  description = "HCP Project ID"
}
# variable "cert" {
#   description = "Certificate for server node"
# }
# variable "ca_cert" {
#   description = "CA Root certificate for servers node"
# }
# variable "cert_key" {
#   description = "Certificate key for node"
# }
# variable "own_certs" {
#   description = "Set to true if putting certs as variables"
#   default = false
# }
# variable "kms_keyring" {
#   description = "KMS Keyring name"
# }
# variable "kms_key" {
#   description = "KMS key name"
# }
# variable "enable_tls" {
#   description = "Enable TLS for the cluster"
#   default = false
# }

# variable "tls_algorithm" {
#   description = "Private key algorithm"
#   default = "RSA"
# }
# variable "ecdsa_curve" {
#     description = "Elliptive curve to use for ECDS algorithm"
#     default = "P521"
# }
# variable "rsa_bits" {
#   description = "Size of RSA algorithm. 2048 by default."
#   default = 2048
# }

# variable "ca_common_name" {
#   default = "vault-ca.local"
# }
# variable "ca_org" {
#   default = "Hashi Vault"
# }
# variable "common_name" {
#   default = "vault.local"
# }
# variable "domains" {
#   description = "Domain for the cert"
# }
