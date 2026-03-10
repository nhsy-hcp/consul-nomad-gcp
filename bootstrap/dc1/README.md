# dc1

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 7.22 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | ~> 7.22 |
| <a name="requirement_http"></a> [http](#requirement\_http) | ~> 3.4 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6 |
| <a name="requirement_tfe"></a> [tfe](#requirement\_tfe) | ~> 0.58 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 7.22.0 |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | 7.22.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.8.1 |
| <a name="provider_tfe"></a> [tfe](#provider\_tfe) | 0.74.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google-beta_google_iam_workload_identity_pool.tfc_pool](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_iam_workload_identity_pool) | resource |
| [google-beta_google_iam_workload_identity_pool_provider.tfc_provider](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_iam_workload_identity_pool_provider) | resource |
| [google_project_iam_member.tfc_service_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.services](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.tfc_service_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_member.tfc_service_account_member](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [random_pet.unique_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet) | resource |
| [tfe_variable.enable_gcp_provider_auth](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/variable) | resource |
| [tfe_variable.gcp_project](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/variable) | resource |
| [tfe_variable.tfc_gcp_service_account_email](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/variable) | resource |
| [tfe_variable.tfc_gcp_workload_provider_name](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/variable) | resource |
| [tfe_variable.workspace](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/variable) | resource |
| [tfe_variable_set.default](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/variable_set) | resource |
| [tfe_workspace.default](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/workspace) | resource |
| [tfe_workspace_variable_set.default](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/workspace_variable_set) | resource |
| [tfe_github_app_installation.default](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/data-sources/github_app_installation) | data source |
| [tfe_project.default](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_gcp_project_id"></a> [gcp\_project\_id](#input\_gcp\_project\_id) | The ID for your GCP project | `string` | n/a | yes |
| <a name="input_gcp_service_list"></a> [gcp\_service\_list](#input\_gcp\_service\_list) | APIs required for the project | `list(string)` | <pre>[<br/>  "iam.googleapis.com",<br/>  "cloudresourcemanager.googleapis.com",<br/>  "sts.googleapis.com",<br/>  "iamcredentials.googleapis.com"<br/>]</pre> | no |
| <a name="input_github_organization"></a> [github\_organization](#input\_github\_organization) | Name of the GitHub organization. | `string` | n/a | yes |
| <a name="input_github_repository"></a> [github\_repository](#input\_github\_repository) | Name of the GitHub repository. | `string` | n/a | yes |
| <a name="input_tfc_hostname"></a> [tfc\_hostname](#input\_tfc\_hostname) | The hostname of the TFC or TFE instance you'd like to use with GCP | `string` | `"app.terraform.io"` | no |
| <a name="input_tfc_organization"></a> [tfc\_organization](#input\_tfc\_organization) | The name of your Terraform Cloud organization | `string` | n/a | yes |
| <a name="input_tfc_project"></a> [tfc\_project](#input\_tfc\_project) | The project under which a workspace will be created | `string` | `"demo"` | no |
| <a name="input_tfc_service_account_iam_roles"></a> [tfc\_service\_account\_iam\_roles](#input\_tfc\_service\_account\_iam\_roles) | IAM roles for TFC service account | `list(string)` | <pre>[<br/>  "roles/compute.admin",<br/>  "roles/dns.admin",<br/>  "roles/iam.serviceAccountAdmin",<br/>  "roles/iam.serviceAccountUser",<br/>  "roles/iam.workloadIdentityPoolAdmin",<br/>  "roles/resourcemanager.projectIamAdmin",<br/>  "roles/storage.admin",<br/>  "roles/viewer"<br/>]</pre> | no |
| <a name="input_tfc_variables"></a> [tfc\_variables](#input\_tfc\_variables) | A map of variables to set in the TFC workspace. | <pre>map(object({<br/>    value     = string<br/>    category  = optional(string, "terraform")<br/>    sensitive = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| <a name="input_tfc_working_directory"></a> [tfc\_working\_directory](#input\_tfc\_working\_directory) | The working directory for the TFC workspace | `string` | `null` | no |
| <a name="input_tfc_workspace"></a> [tfc\_workspace](#input\_tfc\_workspace) | The name of the workspace that you'd like to create and connect to GCP | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
