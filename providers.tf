terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    consul = {
      source  = "hashicorp/consul"
      version = "~> 2.0"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.108.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}


provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

provider "consul" {
  address        = "${local.consul_fqdn}:8501"
  scheme         = "https"
  insecure_https = true
  token          = var.consul_bootstrap_token
}

provider "hcp" {
  project_id = var.hcp_project_id
}

provider "acme" {
  # server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}