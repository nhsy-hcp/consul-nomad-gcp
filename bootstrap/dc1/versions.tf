terraform {
  required_version = ">= 1.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.22"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.22"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.58"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}
