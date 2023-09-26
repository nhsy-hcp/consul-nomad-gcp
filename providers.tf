terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.25.0"
    }
  }
}


provider "google" {
  project = var.gcp_project
  region = var.gcp_region
}
# provider "azure" {
#   version = ">=2.0.0"
#   features {}
# }
# provider "aws" {
#   region = "eu-west"
# } 
