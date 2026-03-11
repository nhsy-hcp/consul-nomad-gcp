# consul-nomad-gcp
This project provides a comprehensive configuration to deploy resilient, multi-datacenter HashiCorp Consul and Nomad clusters on Google Cloud Platform (GCP).
It is a starting point for running containerized and non-containerized workloads, using HCP Terraform for infrastructure management.

## Architecture Overview

*   **Networking:** A custom VPC with public and private subnets. GCP Load Balancers expose the Consul and Nomad UIs, while a separate load balancer handles application traffic.
*   **Compute:** Managed Instance Groups (MIGs) for Consul/Nomad servers and Nomad clients, ensuring high availability across multiple zones.
*   **Image Management:** Packer builds custom GCP images with all necessary software pre-installed, following immutable infrastructure best practices.
*   **Multi-Datacenter & Deployment:** The project is structured for multi-datacenter deployments, managed as distinct configurations in `bootstrap/dc1` designed to be linked to a separate **HCP Terraform workspace**.
*   **Automation:** [Task](https://taskfile.dev/) is used as a command runner to simplify common operations like building images and triggering deployments.

### Core Infrastructure Components
- **main.tf**: Core GCP infrastructure (VPC, firewall, load balancers, DNS)
- **instances.tf**: VM instance templates and managed instance groups
- **consul.tf**: Consul cluster configuration and setup
- **nomad.tf**: Nomad cluster configuration with client/server separation
- **variables.tf**: All Terraform variable definitions
- **outputs.tf**: Environment configuration outputs

### Image Building
- **packer/gcp/**: Packer configurations for building custom GCP images
  - `consul_gcp.pkr.hcl`: Server images with Consul/Nomad
  - `client_gpu.pkr.hcl`: GPU-enabled client images
  - `consul_gcp.auto.pkrvars.hcl`: Packer build variables
- Pre-built scripts in `packer/` for service preparation

### Workload Jobs
- **jobs/**: Nomad job definitions for various workloads
  - Traefik ingress controller
  - Example applications (echoserver, helloworld, jupyter)
  - GPU test jobs
  - Monte Carlo simulation job

## Prerequisites

Before you begin, ensure you have the following:

1.  **HashiCorp Cloud Platform (HCP) Account:**
    *   An active HCP account with an organization and project set up.
    *   HCP Terraform organization with API access configured.
    *   Note: HCP Terraform workspaces will be created automatically via the bootstrap process.

2.  **Google Cloud Platform Project:**
    *   A GCP project with billing enabled.
    *   A Service Account with the following roles:
        *   `roles/compute.admin`
        *   `roles/dns.admin` (if using the DNS feature)
        *   `roles/iam.serviceAccountUser`
        *   `roles/storage.admin` (for Packer image storage)
        *   `roles/viewer`

3.  **Required Software:**
    *   [Terraform](https://www.terraform.io/downloads.html) (v1.10+)
    *   [Packer](https://www.packer.io/downloads.html)
    *   [Task](https://taskfile.dev/installation/)

4.  **Authentication Setup:**
    Authenticate with HCP Terraform:
    ```bash
    terraform login
    ```
    This will open a browser window to generate an API token for HCP Terraform access.

5.  **Configuration Files:**
    Create the required variable files from examples:
    *   `cp bootstrap/dc1/terraform.tfvars.example bootstrap/dc1/terraform.tfvars`
    *   `cp packer/gcp/consul_gcp.auto.pkrvars.hcl.example packer/gcp/consul_gcp.auto.pkrvars.hcl`
    *   `cp backend.tf.example backend.tf`

## HCP Terraform Workspace Setup

**IMPORTANT:** Before deploying infrastructure, you must first set up the HCP Terraform workspace using the bootstrap configuration. This creates the workspace, configures GCP Workload Identity, and sets up all necessary variables.

### Step 1: Configure Bootstrap Variables

Edit `bootstrap/dc1/terraform.tfvars` with your specific values:

```hcl
gcp_project_id      = "your-gcp-project-id"
github_organization = "your-github-org"
github_repository   = "your-repo-name"
tfc_organization    = "your-hcp-terraform-org"
tfc_project         = "your-hcp-terraform-project"
tfc_workspace       = "consul-nomad-gcp-dc1"

tfc_variables = {
  gcp_project              = { value = "your-gcp-project-id" }
  gcp_instance             = { value = "n2-standard-2" }
  hcp_project_id           = { value = "your-hcp-project-id" }
  server_nodes             = { value = 3 }
  nomad_clients            = { value = 2 }
  nomad_gpu_clients        = { value = 0 }
  subnetwork_cidr          = { value = "10.64.0.0/16" }
  cluster_name             = { value = "dc1-hcp" }
  owner                    = { value = "your-name" }
  consul_license           = { value = "your-consul-license", sensitive = true }
  nomad_license            = { value = "your-nomad-license", sensitive = true }
  dns_zone                 = { value = "your-dns-zone" }
  consul_bootstrap_token   = { value = "your-bootstrap-token", sensitive = true }
  nomad_client_preemptible = { value = true }
  letsencrypt_email        = { value = "your-email@example.com" }
}
```

### Step 2: Run Bootstrap Configuration

Navigate to the bootstrap directory and run Terraform to create the HCP workspace:

```bash
cd bootstrap/dc1
terraform init
terraform plan
terraform apply
```

This will:
- Create an HCP Terraform workspace with VCS integration
- Set up GCP Workload Identity for secure authentication
- Configure all necessary workspace variables
- Link the workspace to your GitHub repository

### Step 3: Configure Packer Variables

Edit `packer/gcp/consul_gcp.auto.pkrvars.hcl` with your GCP project settings:

```hcl
# HashiCorp product versions
consul_version = "1.21.2+ent"
nomad_version = "1.10.2+ent"

# Image configuration
image = "consul-nomad-ent"
image_family = "hashistack"
source_image_family = "debian-12"

# GCP configuration
gcp_project = "your-gcp-project-id"

# SSH configuration
sshuser = "packer"
```

### Step 4: Verify Workspace Creation

After successful bootstrap:
1. Check your HCP Terraform organization for the new workspace
2. Verify that all variables are properly configured
3. Ensure the workspace is connected to your GitHub repository

### Step 5: Configure Workspace backend

Edit `backend.tf` with your workspace settings:

```hcl
terraform {
  cloud {
    organization = "__REPLACE__"
    workspaces {
      name    = "__REPLACE__"
      project = "__REPLACE__"
    }
  }
}
```

Initialize the root directory to set up the backend
```bash
terraform init
terraform output
```

## Quick Start (Recommended)

**Prerequisites:**

1.  **Complete workspace setup:** Ensure you have successfully run the bootstrap configuration to create your HCP Terraform workspace.

2.  **Build:**
    Run the `packer` task. This command builds the custom VM image with Packer and then triggers a run in the `primary` HCP Terraform workspace to deploy the infrastructure.

    ```bash
    task packer
    ```
3.  **Deploy:**
    Browse to your HCP Terraform workspace and apply the configuration to deploy the infrastructure.

4.  **Connect to the Cluster:**
    Once the HCP Terraform run is complete, configure your shell to communicate with the cluster.

    ```bash
    eval $(terraform output -raw eval_vars)
    nomad status
    ```
    This sets the necessary `NOMAD_` and `CONSUL_` environment variables.

5.  **Access the UIs:**
    Open the Nomad and Consul web interfaces in your browser.

    ```bash
task nomad:ui
    ```

6.  **Setup:**
    Enable Nomad + Consul Workload Identity integration.

    ```bash
task nomad:setup
    ```

## Configuration Reference

### Required Variable Files
- `bootstrap/dc1/terraform.tfvars`: Bootstrap configuration for HCP workspace setup
- `packer/gcp/consul_gcp.auto.pkrvars.hcl`: Packer build variables

### Key Variables to Configure
- `gcp_project`: Your GCP project ID
- `gcp_region`: Target GCP region
- `cluster_name`: Unique cluster identifier
- `consul_license`: Enterprise license
- `nomad_license`: Enterprise license
- `dns_zone`: Existing GCP DNS zone name

### Environment Variables (Set Automatically)
After deployment, the following environment variables are available via `eval $(task tf:output:dc1)`:
- `CONSUL_HTTP_ADDR`: Consul API endpoint
- `CONSUL_HTTP_TOKEN`: Consul authentication token
- `NOMAD_ADDR`: Nomad API endpoint
- `NOMAD_TOKEN`: Nomad authentication token

## Common Commands (Task Runner)

Use `task` to manage the project.

| Command              | Description                                                        |
| :------------------- | :----------------------------------------------------------------- |
| `task packer`        | Builds only the Packer image.                                     |
| `task clean`         | Deletes the GCP images created by Packer.                         |
| `task nomad:ui`            | Opens the Consul and Nomad UIs in your browser.                   |
| `task job:run`             | Deploys all example Nomad workloads (Traefik, apps).              |
| `task job:purge`           | Stops and purges all running Nomad jobs.                          |
| `task nomad:setup`         | Sets up Nomad + Consul Workload Identity integration.             |
| `task gcp:destroy:mig`     | Destroys all managed instance groups via gcloud CLI.              |
| `task gcp:destroy:lb`      | Destroys all load balancers and related resources via gcloud.     |
| `task gcp:destroy:all`     | Destroys both MIGs and load balancers via gcloud CLI.             |
| `task check-server-logs`   | Check server logs via gcloud SSH and IAP tunnel.                  |
| `task consul:status`       | Check Consul cluster status (members, raft, services).            |
| `task nomad:status`        | Check Nomad cluster status (servers, nodes, jobs).                |
| `task status`              | Check both Consul and Nomad cluster status.                       |

**Note:** Old task names (e.g., `task ui`, `task run-jobs`) are still available as aliases for backward compatibility.

## Project Structure Notes

- Uses Terraform workspaces for multi-datacenter deployments
- Instance groups are managed regionally for high availability
- Load balancers separate server access (Consul/Nomad UIs) from application traffic
- GPU support available through specialized client images and instance types


## Terraform Documentation

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_acme"></a> [acme](#requirement\_acme) | ~> 2.0 |
| <a name="requirement_consul"></a> [consul](#requirement\_consul) | ~> 2.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 7.22 |
| <a name="requirement_hcp"></a> [hcp](#requirement\_hcp) | ~> 0.111 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.2 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_acme"></a> [acme](#provider\_acme) | 2.45.1 |
| <a name="provider_consul"></a> [consul](#provider\_consul) | 2.23.0 |
| <a name="provider_google"></a> [google](#provider\_google) | 7.22.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.8.1 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.2.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [acme_certificate.default](https://registry.terraform.io/providers/vancluever/acme/latest/docs/resources/certificate) | resource |
| [acme_registration.default](https://registry.terraform.io/providers/vancluever/acme/latest/docs/resources/registration) | resource |
| [consul_admin_partition.demo_partitions](https://registry.terraform.io/providers/hashicorp/consul/latest/docs/resources/admin_partition) | resource |
| [google_compute_backend_service.consul](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_service) | resource |
| [google_compute_backend_service.nomad](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_service) | resource |
| [google_compute_firewall.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.internal](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_forwarding_rule.clients_lb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_forwarding_rule) | resource |
| [google_compute_global_address.nomad_consul](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_global_forwarding_rule.consul](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule) | resource |
| [google_compute_global_forwarding_rule.nomad](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule) | resource |
| [google_compute_health_check.consul](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_health_check) | resource |
| [google_compute_health_check.nomad](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_health_check) | resource |
| [google_compute_instance_from_template.vm_cts](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_from_template) | resource |
| [google_compute_instance_template.instance_template](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template) | resource |
| [google_compute_instance_template.nomad_clients](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template) | resource |
| [google_compute_instance_template.nomad_gpu_clients](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template) | resource |
| [google_compute_network.network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_region_backend_service.client_ingress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service) | resource |
| [google_compute_region_health_check.client_ingress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_health_check) | resource |
| [google_compute_region_instance_group_manager.clients_group](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_instance_group_manager) | resource |
| [google_compute_region_instance_group_manager.hashi_group](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_instance_group_manager) | resource |
| [google_compute_region_instance_group_manager.nomad_gpu_clients](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_instance_group_manager) | resource |
| [google_compute_region_per_instance_config.with_script](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_per_instance_config) | resource |
| [google_compute_ssl_certificate.nomad_consul](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_ssl_certificate) | resource |
| [google_compute_subnetwork.subnet](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_compute_target_https_proxy.consul](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_https_proxy) | resource |
| [google_compute_target_https_proxy.nomad](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_https_proxy) | resource |
| [google_compute_url_map.consul](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map) | resource |
| [google_compute_url_map.nomad](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map) | resource |
| [google_dns_record_set.consul](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_dns_record_set.ingress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_dns_record_set.ingress_cname](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_dns_record_set.nomad](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_iam_workload_identity_pool.nomad](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool) | resource |
| [google_iam_workload_identity_pool_provider.nomad_provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_project_iam_member.compute](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gce_pd_csi](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.wi_demo](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.compute](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.gce_pd_csi](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.monte_carlo](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.wi_demo](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_binding.gce_pd_csi](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [google_service_account_iam_binding.gce_pd_csi_attach](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [google_service_account_iam_binding.monte_carlo](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [google_service_account_iam_binding.wi_demo](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [google_storage_bucket.monte_carlo](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_iam_member.monte_carlo](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [null_resource.wait_for_service](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_bytes.consul_encrypt_key](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/bytes) | resource |
| [random_pet.unique_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet) | resource |
| [random_uuid.nomad_bootstrap](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) | resource |
| [tls_private_key.default](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [google_client_config.current](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config) | data source |
| [google_compute_image.client_image](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_image) | data source |
| [google_compute_image.my_image](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_image) | data source |
| [google_compute_zones.available](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_zones) | data source |
| [google_dns_managed_zone.doormat_dns_zone](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/dns_managed_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the cluster | `string` | n/a | yes |
| <a name="input_cni_plugin_version"></a> [cni\_plugin\_version](#input\_cni\_plugin\_version) | Version of CNI plugins to install | `string` | `"v1.9.0"` | no |
| <a name="input_compute_sa_roles"></a> [compute\_sa\_roles](#input\_compute\_sa\_roles) | IAM roles to assign to the compute service account | `set(string)` | <pre>[<br/>  "roles/logging.logWriter",<br/>  "roles/monitoring.metricWriter",<br/>  "roles/monitoring.viewer",<br/>  "roles/stackdriver.resourceMetadata.writer",<br/>  "roles/compute.networkViewer",<br/>  "roles/storage.objectViewer"<br/>]</pre> | no |
| <a name="input_consul_bootstrap_token"></a> [consul\_bootstrap\_token](#input\_consul\_bootstrap\_token) | Terraform Cloud token to use for CTS | `string` | n/a | yes |
| <a name="input_consul_cni_version"></a> [consul\_cni\_version](#input\_consul\_cni\_version) | Version of Consul CNI plugin to install | `string` | `"1.9.5"` | no |
| <a name="input_consul_license"></a> [consul\_license](#input\_consul\_license) | Consul Enterprise license text | `string` | n/a | yes |
| <a name="input_consul_partitions"></a> [consul\_partitions](#input\_consul\_partitions) | List of Consul Admin Partitions | `list(string)` | `[]` | no |
| <a name="input_dns_zone"></a> [dns\_zone](#input\_dns\_zone) | An already existing DNS zone in your GCP project | `string` | `null` | no |
| <a name="input_enable_cts"></a> [enable\_cts](#input\_enable\_cts) | Set it to true to deploy a node for CTS | `string` | `"false"` | no |
| <a name="input_gcp_instance"></a> [gcp\_instance](#input\_gcp\_instance) | Machine type for nodes | `string` | n/a | yes |
| <a name="input_gcp_project"></a> [gcp\_project](#input\_gcp\_project) | Cloud project | `string` | n/a | yes |
| <a name="input_gcp_region"></a> [gcp\_region](#input\_gcp\_region) | Google Cloud region | `string` | `"europe-west1"` | no |
| <a name="input_gcp_zones"></a> [gcp\_zones](#input\_gcp\_zones) | Zones to spread the clients. This is a list of zones | `list(string)` | <pre>[<br/>  "europe-west1-c"<br/>]</pre> | no |
| <a name="input_hcp_project_id"></a> [hcp\_project\_id](#input\_hcp\_project\_id) | HCP Project ID | `string` | n/a | yes |
| <a name="input_image_family"></a> [image\_family](#input\_image\_family) | Image family to use for compute instances | `string` | `"hashistack"` | no |
| <a name="input_letsencrypt_email"></a> [letsencrypt\_email](#input\_letsencrypt\_email) | Email for Let's Encrypt | `string` | n/a | yes |
| <a name="input_nomad_client_disk_size"></a> [nomad\_client\_disk\_size](#input\_nomad\_client\_disk\_size) | Disk size for Nomad nodes | `number` | `100` | no |
| <a name="input_nomad_client_machine_type"></a> [nomad\_client\_machine\_type](#input\_nomad\_client\_machine\_type) | Machine type for nodes | `string` | `"n1-standard-4"` | no |
| <a name="input_nomad_client_preemptible"></a> [nomad\_client\_preemptible](#input\_nomad\_client\_preemptible) | Use preemptible VMs for Nomad clients | `bool` | `false` | no |
| <a name="input_nomad_clients"></a> [nomad\_clients](#input\_nomad\_clients) | number of client nodes | `number` | `2` | no |
| <a name="input_nomad_gpu_clients"></a> [nomad\_gpu\_clients](#input\_nomad\_gpu\_clients) | number of gpu client nodes | `number` | `0` | no |
| <a name="input_nomad_license"></a> [nomad\_license](#input\_nomad\_license) | Nomad Enterprise license text | `string` | n/a | yes |
| <a name="input_owner"></a> [owner](#input\_owner) | Owner of the cluster | `string` | n/a | yes |
| <a name="input_server_nodes"></a> [server\_nodes](#input\_server\_nodes) | number of server nodes | `number` | `3` | no |
| <a name="input_subnetwork_cidr"></a> [subnetwork\_cidr](#input\_subnetwork\_cidr) | CIDR for the subnetwork | `string` | `"10.2.0.0/16"` | no |
| <a name="input_tfc_token"></a> [tfc\_token](#input\_tfc\_token) | Terraform Cloud token to use for CTS | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_CONSUL_HTTP_ADDR"></a> [CONSUL\_HTTP\_ADDR](#output\_CONSUL\_HTTP\_ADDR) | Consul HTTPS URL for API access |
| <a name="output_CONSUL_TOKEN"></a> [CONSUL\_TOKEN](#output\_CONSUL\_TOKEN) | Consul bootstrap token for authentication |
| <a name="output_NOMAD_ADDR"></a> [NOMAD\_ADDR](#output\_NOMAD\_ADDR) | Nomad HTTPS URL for API access |
| <a name="output_NOMAD_TOKEN"></a> [NOMAD\_TOKEN](#output\_NOMAD\_TOKEN) | Nomad bootstrap token for authentication |
| <a name="output_apigw_load_balancers"></a> [apigw\_load\_balancers](#output\_apigw\_load\_balancers) | IP addresses of the API gateway load balancers |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Cluster name used as a prefix for GCP resources |
| <a name="output_eval_vars"></a> [eval\_vars](#output\_eval\_vars) | Environment variables for Consul and Nomad CLI access |
| <a name="output_gcp_project"></a> [gcp\_project](#output\_gcp\_project) | GCP project ID where resources are deployed |
| <a name="output_gcp_region"></a> [gcp\_region](#output\_gcp\_region) | GCP region where resources are deployed |
| <a name="output_gcp_wi_csi_google_pd_service_account"></a> [gcp\_wi\_csi\_google\_pd\_service\_account](#output\_gcp\_wi\_csi\_google\_pd\_service\_account) | Email of the GCP service account for CSI Google PD driver |
| <a name="output_gcp_wi_demo_service_account"></a> [gcp\_wi\_demo\_service\_account](#output\_gcp\_wi\_demo\_service\_account) | Email of the GCP service account for workload identity demo |
| <a name="output_gcp_wi_monte_carlo_service_account"></a> [gcp\_wi\_monte\_carlo\_service\_account](#output\_gcp\_wi\_monte\_carlo\_service\_account) | Email of the GCP service account for Monte Carlo workloads |
| <a name="output_gcp_wi_provider"></a> [gcp\_wi\_provider](#output\_gcp\_wi\_provider) | GCP Workload Identity provider name for Nomad |
| <a name="output_ingress_dashboard_url"></a> [ingress\_dashboard\_url](#output\_ingress\_dashboard\_url) | URL for accessing the Traefik dashboard |
| <a name="output_ingress_fqdn"></a> [ingress\_fqdn](#output\_ingress\_fqdn) | Fully qualified domain name for the ingress endpoint |
| <a name="output_ingress_url"></a> [ingress\_url](#output\_ingress\_url) | Base HTTPS URL for the ingress endpoint |
| <a name="output_letsencrypt_email"></a> [letsencrypt\_email](#output\_letsencrypt\_email) | Email address for Let's Encrypt certificate registration |
| <a name="output_monte_carlo_bucket"></a> [monte\_carlo\_bucket](#output\_monte\_carlo\_bucket) | Name of the GCS bucket for Monte Carlo simulation results |
| <a name="output_partitions"></a> [partitions](#output\_partitions) | List of Consul admin partitions assigned to Nomad clients |
<!-- END_TF_DOCS -->
