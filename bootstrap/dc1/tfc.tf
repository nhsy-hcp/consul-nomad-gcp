# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

data "tfe_github_app_installation" "default" {
  name = var.github_organization
}

data "tfe_project" "default" {
  name         = var.tfc_project
  organization = var.tfc_organization
}

# resource "tfe_project" "default" {
#   name         = var.tfc_project
#   organization = var.tfc_organization
# }

# Runs in this workspace will be automatically authenticated
# to GCP with the permissions set in the GCP policy.
#
# https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/workspace
resource "tfe_workspace" "default" {
  name                = var.tfc_workspace
  auto_apply          = true
  description         = "Terraform Cloud workspace for GCP Workload Identity integration"
  organization        = var.tfc_organization
  project_id          = data.tfe_project.default.id
  speculative_enabled = true
  tag_names           = ["gcp", "workload-identity"]
  terraform_version   = ">= 1.10.0"
  trigger_patterns    = ["*.tf", "*.tfvars"]

  vcs_repo {
    branch                     = "main"
    identifier                 = format("%s/%s", var.github_organization, var.github_repository)
    github_app_installation_id = data.tfe_github_app_installation.default.id
  }
  working_directory = var.tfc_working_directory
}

resource "tfe_variable_set" "default" {
  name         = "${var.tfc_workspace}-varset"
  description  = "GCP Workload Identity Variables"
  organization = var.tfc_organization
}

resource "tfe_workspace_variable_set" "default" {
  variable_set_id = tfe_variable_set.default.id
  workspace_id    = tfe_workspace.default.id
}

# The following variables must be set to allow runs
# to authenticate to GCP.
#
# https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/variable
resource "tfe_variable" "enable_gcp_provider_auth" {
  # workspace_id = tfe_workspace.default.id
  variable_set_id = tfe_variable_set.default.id

  key      = "TFC_GCP_PROVIDER_AUTH"
  value    = "true"
  category = "env"

  description = "Enable the Workload Identity integration for GCP."
}

# The provider name contains the project number, pool ID,
# and provider ID. This information can be supplied using
# this TFC_GCP_WORKLOAD_PROVIDER_NAME variable, or using
# the separate TFC_GCP_PROJECT_NUMBER, TFC_GCP_WORKLOAD_POOL_ID,
# and TFC_GCP_WORKLOAD_PROVIDER_ID variables below if desired.
#
resource "tfe_variable" "tfc_gcp_workload_provider_name" {
  # workspace_id = tfe_workspace.default.id
  variable_set_id = tfe_variable_set.default.id

  key      = "TFC_GCP_WORKLOAD_PROVIDER_NAME"
  value    = google_iam_workload_identity_pool_provider.tfc_provider.name
  category = "env"

  description = "The workload provider name to authenticate against."
}

resource "tfe_variable" "tfc_gcp_service_account_email" {
  # workspace_id = tfe_workspace.default.id
  variable_set_id = tfe_variable_set.default.id

  key      = "TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL"
  value    = google_service_account.tfc_service_account.email
  category = "env"

  description = "The GCP service account email runs will use to authenticate."
}

resource "tfe_variable" "workspace" {
  for_each = var.tfc_variables
  # workspace_id = tfe_workspace.default.id
  variable_set_id = tfe_variable_set.default.id

  key       = each.key
  category  = each.value.category
  sensitive = each.value.sensitive
  value     = each.value.value
}