terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
    random = {
      source = "hashicorp/random"
    }
    tfe = {
      source = "hashicorp/tfe"
    }
    http = {
      source = "hashicorp/http"
    }
  }
}