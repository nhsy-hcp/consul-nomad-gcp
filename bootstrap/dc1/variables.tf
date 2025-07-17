# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "tfc_gcp_audience" {
  type        = string
  default     = ""
  description = "The audience value to use in run identity tokens if the default audience value is not desired."
}

variable "tfc_hostname" {
  type        = string
  default     = "app.terraform.io"
  description = "The hostname of the TFC or TFE instance you'd like to use with GCP"
}

variable "tfc_organization" {
  type        = string
  description = "The name of your Terraform Cloud organization"
}

variable "tfc_project" {
  type        = string
  default     = "demo"
  description = "The project under which a workspace will be created"
}

variable "tfc_workspace" {
  type        = string
  description = "The name of the workspace that you'd like to create and connect to GCP"
}

variable "tfc_working_directory" {
  type        = string
  default     = null
  description = "The working directory for the TFC workspace"
}

variable "gcp_project_id" {
  type        = string
  description = "The ID for your GCP project"
}

variable "gcp_service_list" {
  description = "APIs required for the project"
  type        = list(string)
  default = [
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "sts.googleapis.com",
    "iamcredentials.googleapis.com"
  ]
}

variable "tfc_service_account_iam_roles" {
  description = "IAM roles for TFC service account"
  type        = list(string)
  default = [
    "roles/compute.admin",
    "roles/dns.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/viewer",
  ]
}

variable "github_organization" {
  type        = string
  description = "Name of the GitHub organization."
}

variable "github_repository" {
  type        = string
  description = "Name of the GitHub repository."
}

variable "tfc_variables" {
  type = map(object({
    value     = string
    category  = optional(string, "terraform")
    sensitive = optional(bool, false)
  }))
  description = "A map of variables to set in the TFC workspace."
  default     = {}
}