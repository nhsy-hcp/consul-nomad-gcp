variable "gcp_project" {
  description = "Google Cloud Project ID"
}

variable "gcp_wi_provider" {
  description = "Google Cloud IAM Workload Identity Pool Provider Name"
}

variable "gcp_service_account" {
  description = "Google Cloud Service Account Email"
}

job "gce-pd-csi-controller" {
  type = "service"
  group "controller" {
    count = 1
    restart {
      attempts = 0
      interval = "10m"
      delay    = "15s"
      mode     = "fail"
    }

    task "plugin" {
      driver = "docker"
      env {
        GOOGLE_APPLICATION_CREDENTIALS = "/secrets/creds.json"
      }

      meta {
        project      = var.gcp_project
        wid_provider = var.gcp_wi_provider
        service_acct = var.gcp_service_account
      }

      # Nomad Workload Identity for authenticating with Google Federated
      # Workload Identity Provider
      identity {
        # Name must match the file parameter in the credential config template
        # below *and* the principal used in the Service Account IAM Binding.
        name = "csi"
        file = true

        # Audience must match the audience specified in the Google IAM Workload
        # Identity Pool Provider.
        aud  = ["gcp"]
        ttl  = "1h"
        filepath = "/secrets/nomad_csi.jwt"
      }

      # Credential file for Google's Cloud SDK
      # Can be generated with:
      #   gcloud iam workload-identity-pools create-cred-config
      template {
        destination = "/secrets/creds.json"
        data        = <<EOF
{
  "type": "external_account",
  "audience": "//iam.googleapis.com/{{ env "NOMAD_META_wid_provider" }}",
  "subject_token_type": "urn:ietf:params:oauth:token-type:jwt",
  "token_url": "https://sts.googleapis.com/v1/token",
  "service_account_impersonation_url": "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/{{ env "NOMAD_META_service_acct" }}:generateAccessToken",
  "credential_source": {
    "file": "/secrets/nomad_csi.jwt",
    "format": {
      "type": "text"
    }
  }
}
EOF
      }

      config {
        image = "gcr.io/gke-release/gcp-compute-persistent-disk-csi-driver:v1.20.2-gke.0"
        args = [
          "--endpoint=unix:///csi/csi.sock",
          "--v=6",
          "--logtostderr",
          "--run-node-service=false"
        ]
      }

      csi_plugin {
        id        = "gce-pd"
        type      = "controller"
        mount_dir = "/csi"
      }

      resources {
        memory = 256
      }
    }
  }
}

#       # Restart policy
#       restart {
#         attempts = 0
#         interval = "10m"
#         delay    = "15s"
#         mode     = "fail"
#       }
#       identity {
#         # Name must match the file parameter in the credential config template
#         # below *and* the principal used in the Service Account IAM Binding.
#         name = "tutorial"
#         file = true
#
#         # Audience must match the audience specified in the Google IAM Workload
#         # Identity Pool Provider.
#         aud = ["gcp"]
#         ttl = "1h"
#       }
#
#       template {
#         destination = "local/cred.json"
#         data        = <<EOF
# {
#   "type": "external_account",
#   "audience": "//iam.googleapis.com/{{ env "NOMAD_META_wi_provider" }}",
#   "subject_token_type": "urn:ietf:params:oauth:token-type:jwt",
#   "token_url": "https://sts.googleapis.com/v1/token",
#   "service_account_impersonation_url": "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/{{ env "NOMAD_META_service_account" }}:generateAccessToken",
#   "credential_source": {
#     "file": "/secrets/nomad_tutorial.jwt",
#     "format": {
#       "type": "text"
#     }
#   }
# }
# EOF
#       }


      # image = "gcr.io/gke-release/gcp-compute-persistent-disk-csi-driver:v1.20.2-gke.0"


      # env {
      #   GOOGLE_APPLICATION_CREDENTIALS = "/local/cred.json"
      # }


  # meta {
  #   project         = var.gcp_project
  #   wi_provider     = var.gcp_wi_provider
  #   service_account = var.gcp_service_account
  # }