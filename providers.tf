terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.25.0"
    }
    consul = {
      source = "hashicorp/consul"
      version = "2.20.0"
    }
    hcp = {
      source = "hashicorp/hcp"
      version = "0.87.1"
    }
  }
}


provider "google" {
  project = var.gcp_project
  region = var.gcp_region
}

provider "consul" {
  address = "${trimsuffix(google_dns_record_set.dns.name,".")}:8501"
  scheme = "https"
  insecure_https = true
  token = var.consul_bootstrap_token
}
provider "hcp" {
  project_id = var.hcp_project_id
}
# provider "azure" {
#   version = ">=2.0.0"
#   features {}
# }
# provider "aws" {
#   region = "eu-west"
# } 
