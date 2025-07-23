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
    eval $(task tf-output-dc1)
    ```
    This sets the necessary `NOMAD_` and `CONSUL_` environment variables.

5.  **Access the UIs:**
    Open the Nomad and Consul web interfaces in your browser.

    ```bash
    task ui
    ```

6.  **Setup:**
    Enable Nomad + Consul Workload Identity integration.

    ```bash
    task setup
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
After deployment, the following environment variables are available via `eval $(task tf-output-dc1)`:
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
| `task ui`            | Opens the Consul and Nomad UIs in your browser.                   |
| `task run-jobs`      | Deploys all example Nomad workloads (Traefik, apps).              |
| `task purge-jobs`    | Stops and purges all running Nomad jobs.                          |
| `task tf-output-dc1` | Fetches and prints connection variables from the `dc1` workspace. |

## Project Structure Notes

- Uses Terraform workspaces for multi-datacenter deployments
- Instance groups are managed regionally for high availability
- Load balancers separate server access (Consul/Nomad UIs) from application traffic
- GPU support available through specialized client images and instance types
