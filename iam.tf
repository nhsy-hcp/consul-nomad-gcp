resource "google_service_account" "compute" {
  account_id = "compute-${var.cluster_name}-sa-${local.unique_id}"
}

resource "google_project_iam_member" "compute" {
  for_each = var.compute_sa_roles
  role     = each.value
  member   = "serviceAccount:${google_service_account.compute.email}"
  project  = var.gcp_project
}
