# Architecture Deep Dive

This document provides a technical deep dive into the architecture of the `terraform-gcp-consul-nomad` project. It is intended for architects and engineers who want to understand the underlying infrastructure and design decisions.

## Infrastructure Overview

The project deploys a highly available, secure, and scalable HashiCorp stack (Consul and Nomad) on Google Cloud Platform. It leverages managed services where appropriate while maintaining control over the core orchestration layer.

## Network Architecture

### VPC and Subnets
- **Custom VPC:** A dedicated VPC (`${var.cluster_name}-network`) isolates the cluster traffic.
- **Regional Subnet:** A single regional subnet is used for all nodes, simplifying internal routing.
- **Internal Communication:** Firewall rules allow full TCP/UDP communication between nodes tagged with the cluster name, facilitating Consul's gossip protocol and Nomad's RPC.

### Load Balancing
The architecture employs two distinct types of load balancers:

1.  **Management Load Balancer (Global External Managed HTTP(S)):**
    - Exposes the Consul and Nomad UIs/APIs.
    - Uses a single Global IP address.
    - Terminates TLS using certificates managed via the ACME (Let's Encrypt) provider.
    - Routes traffic based on port: `4646` for Nomad and `8501` for Consul.

2.  **Application Ingress Load Balancer (Regional External TCP):**
    - Handles incoming traffic for workloads running on Nomad.
    - Forwards ports `80`, `443`, `8443`, and `8080` to the Nomad client MIGs.
    - Typically interfaces with an ingress controller like Traefik running on the clients.

### DNS
- **Cloud DNS:** Manages public record sets for the cluster endpoints (e.g., `nomad.example.com`, `consul.example.com`).
- **Service Discovery:** Internally, Consul provides DNS-based service discovery for all registered workloads.

## Compute and Orchestration

### Immutable Infrastructure
The project follows an immutable infrastructure pattern:
- **Packer:** Custom GCP images are built using Packer, pre-installing Consul, Nomad, Docker, and necessary CNI plugins.
- **Versioning:** Images are versioned and managed via GCP Image Families.

### Server Cluster (Consul & Nomad)
- **Unified Servers:** For efficiency in smaller deployments, both Consul and Nomad server agents run on the same set of VMs.
- **Managed Instance Group (MIG):** A regional MIG ensures that server nodes are spread across three zones for high availability.
- **Stateful Storage:** Server nodes use stateful disks to persist Consul and Nomad data, ensuring quorum is maintained during node replacements.
- **Quorum:** Typically deployed with 3 or 5 nodes to survive zone failures.

### Client Clusters
Nomad clients are separated into their own MIGs:
- **Standard Clients:** General-purpose workloads.
- **GPU Clients:** Specialized MIGs using instances with NVIDIA Tesla T4 GPUs, including the necessary drivers pre-installed via a specialized Packer template.
- **Autoscaling:** MIGs can be configured to scale based on CPU utilization or other metrics.
- **Preemptible VMs:** Optional support for using preemptible VMs for client nodes to reduce costs.

## Service Mesh (Consul)

- **Connect:** Consul Connect is enabled, providing mTLS-secured service-to-service communication.
- **Admin Partitions:** Supports Consul Enterprise Admin Partitions, allowing for logical isolation of workloads and configuration within a single cluster.
- **Transparent Proxy:** Workloads can leverage transparent proxying for seamless integration into the mesh.

## Workload Orchestration (Nomad)

- **Task Drivers:** Supports Docker, Exec, and Java drivers out of the box.
- **Workload Identity:** Integrates with GCP Workload Identity (see Security section).
- **Consul Integration:** Native integration for service registration and configuration (Consul Template).

## Security and Identity

### TLS and Encryption
- **External TLS:** Let's Encrypt certificates protect public endpoints.
- **Internal TLS:** Consul and Nomad communicate internally over TLS.
- **Gossip Encryption:** All gossip traffic is encrypted using a shared secret key.

### Identity Federation (Workload Identity)
This project implements a sophisticated identity model:
1.  **Nomad Workload Identity:** Nomad issues OIDC tokens to tasks.
2.  **GCP Workload Identity Federation:** A GCP Workload Identity Pool is configured to trust Nomad as an OIDC issuer.
3.  **Service Account Mapping:** Nomad tasks can "assume" GCP Service Accounts based on their Nomad identity (namespace, job name, etc.).
4.  **Secure Access:** This allows workloads to access GCP resources (GCS, BigQuery, etc.) without needing long-lived credentials or service account keys.

## Storage

- **GCE Persistent Disk CSI:** Nomad is configured with the GCE PD CSI driver, allowing stateful workloads to dynamically provision and attach GCP persistent disks.
- **Object Storage (GCS):** Integrated for workloads requiring blob storage, with permissions managed via Workload Identity.

## High Availability and Scalability

- **Multi-Zone Deployment:** All core components are spread across multiple GCP zones.
- **Self-Healing:** GCP MIGs automatically recreate unhealthy instances.
- **Multi-Datacenter:** The project structure facilitates deploying multiple independent datacenters (e.g., `dc1`, `dc2`) and linking them at the Consul/Nomad level.
