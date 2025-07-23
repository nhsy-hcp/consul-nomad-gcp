variable "gcp_project" {
  description = "Google Cloud Project ID"
}

variable "gcp_wi_provider" {
  description = "Google Cloud IAM Workload Identity Pool Provider Name"
}

variable "gcp_service_account" {
  description = "Google Cloud Service Account Email"
}

job "gcp-wi-demo" {
  type = "batch"

  group "batch" {

    task "gcloud" {

      restart {
        attempts = 0
      }

      driver = "docker"

      # Example batch job which authenticates using its workload identity and
      # uploads a templated file to the specified GCS Bucket.
      config {
        command        = "/bin/sh"
        args = [
          "-c",
          <<EOF
            echo 'running; check stderr' && \
            cat local/cred.json && \
            gcloud auth login --cred-file=/local/cred.json && \
            gcloud info && \
            gcloud projects list && \
            gcloud compute instances list && \
            sleep 86400
          EOF
        ]
        image          = "google/cloud-sdk:529.0.0"
        auth_soft_fail = true
      }

      meta {
        project         = var.gcp_project
        wi_provider     = var.gcp_wi_provider
        service_account = var.gcp_service_account
      }

      # Nomad Workload Identity for authenticating with Google Federated
      # Workload Identity Provider
      identity {
        # Name must match the file parameter in the credential config template
        # below *and* the principal used in the Service Account IAM Binding.
        name = "tutorial"
        file = true

        # Audience must match the audience specified in the Google IAM Workload
        # Identity Pool Provider.
        aud  = ["gcp"]
        ttl  = "1h"
      }

      # Example file for uploading to GCS
      template {
        destination = "local/test.txt"
        data        = <<EOF
Job:          {{ env "NOMAD_JOB_NAME" }}
Alloc:        {{ env "NOMAD_ALLOC_ID" }}
Project:      {{ env "NOMAD_META_project" }}
WID Provider: {{ env "NOMAD_META_wi_provider" }}
Service Acct: {{ env "NOMAD_META_service_account" }}
EOF
      }

      # Credential file for Google's Cloud SDK
      # Can be generated with:
      #   gcloud iam workload-identity-pools create-cred-config
      template {
        destination = "local/cred.json"
        data        = <<EOF
{
  "type": "external_account",
  "audience": "//iam.googleapis.com/{{ env "NOMAD_META_wi_provider" }}",
  "subject_token_type": "urn:ietf:params:oauth:token-type:jwt",
  "token_url": "https://sts.googleapis.com/v1/token",
  "service_account_impersonation_url": "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/{{ env "NOMAD_META_service_account" }}:generateAccessToken",
  "credential_source": {
    "file": "/secrets/nomad_tutorial.jwt",
    "format": {
      "type": "text"
    }
  }
}
EOF
      }

      resources {
        cpu    = 500
        memory = 600
      }

    }
  }
}