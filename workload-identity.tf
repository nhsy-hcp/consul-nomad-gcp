# data "http" "jwks" {
#   url         = "${local.nomad_https_url}/.well-known/jwks.json"
#   ca_cert_pem = acme_certificate.default.issuer_pem
#
#   lifecycle {
#     postcondition {
#       condition     = self.status_code == 200
#       error_message = "Failed to get JWKS from Nomad server at ${local.nomad_fqdn}. Ensure Nomad is running and accessible."
#     }
#   }
#   depends_on = [
#     null_resource.wait_for_service
#   ]
# }

# Workload Identity Pool
resource "google_iam_workload_identity_pool" "nomad" {
  # GCP disallows reusing pool names within 30 days, so use a random name.
  workload_identity_pool_id = "nomad-pool-${local.unique_id}"
}

# Workload Identity Provider
resource "google_iam_workload_identity_pool_provider" "nomad_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.nomad.workload_identity_pool_id
  workload_identity_pool_provider_id = "nomad-provider"
  display_name                       = "Nomad Provider"
  description                        = "OIDC identity pool provider"

  # Map the Nomad Workload Identity's subject to Google's subject. This ties
  # the Google Workload Identity Pool Provider to the specific tutorial job.
  #
  # If changed then the principal used for the Google Service Account IAM
  # Binding must be changed below as well.
  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }

  oidc {
    # Allowed audiences must match the aud parameter of the Nomad Workload
    # Identity being used.
    allowed_audiences = ["gcp"]
    issuer_uri        = local.nomad_https_url
    # jwks_json         = data.http.jwks.request_body
  }
}

# Service Account which Nomad Workload Identity demo will map to.
resource "google_service_account" "wi_demo" {
  account_id   = "nomad-wi-demo-sa-${local.unique_id}"
  display_name = "Nomad WI demo Service Account"
}

resource "google_project_iam_member" "wi_demo" {
  for_each = toset([
    "roles/viewer",
  ])
  project = var.gcp_project
  role    = each.value
  member  = "serviceAccount:${google_service_account.wi_demo.email}"
}

# IAM Binding links the Workload Identity Pool -> Service Account.
resource "google_service_account_iam_binding" "wi_demo" {
  service_account_id = google_service_account.wi_demo.name

  role = "roles/iam.workloadIdentityUser"

  members = [
    # google_workload_identity_pool lacks an attribute for the principal, so
    # string format it manually to look like:
    #principal://iam.googleapis.com/projects/PROJECT_NUM/locations/global/workloadIdentityPools/POOL_NAME/subject/SUBJECT_MAPPING
    "principal://iam.googleapis.com/${google_iam_workload_identity_pool.nomad.name}/subject/global:default:gcp-wi-demo:batch:gcloud:tutorial"
  ]
}

# Service Account which Nomad Workload Identities will map to.
resource "google_service_account" "gce_pd_csi" {
  account_id   = "nomad-gce-pd-csi-sa-${local.unique_id}"
  display_name = "Nomad GCE PD CSI Service Account"
}

resource "google_project_iam_member" "gce_pd_csi" {
  for_each = toset(["roles/compute.instanceAdmin.v1"])

  project = var.gcp_project
  role    = each.value
  member  = "serviceAccount:${google_service_account.gce_pd_csi.email}"
}

resource "google_service_account_iam_binding" "gce_pd_csi" {
  service_account_id = google_service_account.gce_pd_csi.name

  role = "roles/iam.workloadIdentityUser"

  members = [
    # google_workload_identity_pool lacks an attribute for the principal, so
    # string format it manually to look like:
    #principal://iam.googleapis.com/projects/PROJECT_NUM/locations/global/workloadIdentityPools/POOL_NAME/subject/SUBJECT_MAPPING
    "principal://iam.googleapis.com/${google_iam_workload_identity_pool.nomad.name}/subject/global:default:gce-pd-csi-controller:controller:plugin:csi"
  ]
}

resource "google_service_account_iam_binding" "gce_pd_csi_attach" {
  service_account_id = google_service_account.compute.name

  role = "roles/iam.serviceAccountUser"

  members = [
    "serviceAccount:${google_service_account.gce_pd_csi.email}"
  ]
}

resource "google_storage_bucket" "monte_carlo" {
  name     = "${data.google_client_config.current.project}-monte-carlo-${local.unique_id}"
  location = var.gcp_region

  uniform_bucket_level_access = true

  # Enable Object Versioning to keep track of changes
  versioning {
    enabled = true
  }

  # Enable Object Lifecycle Management to delete old versions after a period
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 1
    }
  }
}

# Service Account which Nomad Workload Identities will map to.
resource "google_service_account" "monte_carlo" {
  account_id   = "nomad-monte-carlo-sa-${local.unique_id}"
  display_name = "Nomad Monte Carlo Service Account"
}

resource "google_storage_bucket_iam_member" "monte_carlo" {
  bucket = google_storage_bucket.monte_carlo.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.monte_carlo.email}"
}

resource "google_service_account_iam_binding" "monte_carlo" {
  service_account_id = google_service_account.monte_carlo.name

  role = "roles/iam.workloadIdentityUser"

  members = [
    # google_workload_identity_pool lacks an attribute for the principal, so
    # string format it manually to look like:
    #principal://iam.googleapis.com/projects/PROJECT_NUM/locations/global/workloadIdentityPools/POOL_NAME/subject/SUBJECT_MAPPING
    "principal://iam.googleapis.com/${google_iam_workload_identity_pool.nomad.name}/subject/global:default:monte-carlo-batch:simulation:monte-carlo:tutorial"
  ]
}