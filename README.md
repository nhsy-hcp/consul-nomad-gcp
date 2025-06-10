# Deploy Consul and Nomad demo into GCP
> Disclosure: This is not an official HashiCorp repository and it is a continuous work in progress, so you might find some non-working configurations in your environment.

This is a WIP...

## Requirements
* An existing Google Cloud Platform project with permissions to create the different compute instances resources. This repo has been tested with a service account with the following roles in GCP:
  * `roles/compute.admin`
  * `roles/dns.admin`
  * `roles/iam.serviceAccountUser`
  * `roles/viewer`

* A HashiCorp Terraform CLI with version 1.10+. Also you can use [HCP Terraform](https://cloud.hashicorp.com/products/terraform), as done with this repository tests
* HashiCorp Packer to build the images used by the Terraform configuration. Optionally you can use [HCP Packer](https://developer.hashicorp.com/hcp/docs/packer)
 to manage your images. In that case you would need to define the `hcp_packer_*` Terraform variables.


## Build Image
First you need to build your image for Consul and Nomad with Packer.

Change the versions in the file `packer/gcp/consul_gcp.auth.pkvars.hcl` and use the right GCP project:
```hcl
consul_version = "1.21.0+ent"
nomad_version = "1.10.0+ent"
...
gcp_project = "<gcp_project_id>"
source_image_family = "debian-12"
```

> NOTE: This Packer build configuration is designed to use your specific HCP Packer bucket. If you don't want to use HCP Packer, just comment the following lines from `consul_gcp.pkr.hcl` file:
> ```hcl
> hcp_packer_registry {
>    bucket_name = var.hcp_bucket_name
>    description = <<EOT
>Image for Consul, Nomad and Vault
>    EOT
>    bucket_labels = {
>      "hashicorp"    = "Vault,Consul,Nomad",
>      "owner" = "dcanadillas",
>      "platform" = "hashicorp",
>    }
>  }

To build for GCP:
```bash
cd packer/gcp
packer build .
```

## Deploy infrastructure
Configure the Terraform project with your variables values in `terraform.auto.tfvars`. It is important to set your `gcp_project_id`. Use an example like the following with your values:
```hcl
gcp_region = "europe-southwest1"
gcp_project = "<gcp_project_id"
gcp_instance = "n2-standard-2"
numnodes = 3
numclients = 2
# One of the names that you should see from "gcloud iam service-accounts list --format="table(NAME)""
gcp_sa = "<gcp_owner_service_Account>"
cluster_name = "hashistack-gcp-demo"
owner = "<use_an_alias>"
consul_license = "<your_Consul_Ent_license_string>"
nomad_license = "<your_Nomad_Ent_license_string>"
dns_zone = "<your_existing_dns_zone_name>"
consul_bootstrap_token = "ConsulR0cks"
```

This variable file definition will deploy a 3 node cluster for the Consul and Nomad servers (Nomad and Consul servers will run on the same node, which is not the best practice, but enough for demoing) and 2 nodes for Nomad clients (also the Consul clients).

If you used HCP Packer when building your image, you can use the HCP Packer image metadata by using the following Terraform variables:
* `hcp_packer_bucket` used in the Packer build
* `hcp_packer_channel` (set it to latest, unless you have defined a different [HCP Packer channel](https://developer.hashicorp.com/hcp/docs/packer/manage/channel))
* `use_hcp_packer = true`

### Using a GCP DNS Zone
If you have a [DNS Zone](https://cloud.google.com/dns/docs/zones) defined in GCP you can tell Terraform to create the registries to provide an FQDN to your Consul and Nomad clusters in the format `hashi-${var.cluster_name}.<your_zone_domain>`

You just need to enable the following Terraform variable to use your DNS zone:
* `dns_zone = <your_dns_zone_name>`

For example, if you have a DNS zone called "my-example-zone" with the domain `example.com`, by setting `dns_zone = my-example-zone` amd `cluster_name = demo-cluster`, you would have your clusters in the following urls:
* Nomad: http://demo-cluster.example.com:4646
* Consul: https://demo-cluster.example.com:8501

## Set your environment to connect to Nomad and Consul

This Terraform configuration will ouput the values to configure your terminal to connect to the Nomad and Consul clusters deployed. You just need to use the `eval_vars` output:
```bash
eval $(terraform output -raw eval_vars)
```

