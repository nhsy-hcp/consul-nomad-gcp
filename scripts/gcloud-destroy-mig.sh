#!/bin/bash
set -euo pipefail

# Destroy managed instance groups via gcloud
# This script destroys all server, client, and GPU client managed instance groups

echo "Destroying managed instance groups..."

# Get cluster name and region from Terraform outputs or use defaults
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "dc1-hcp")
REGION=$(terraform output -raw gcp_region 2>/dev/null || echo "europe-west1")

echo "Cluster: ${CLUSTER_NAME}"
echo "Region: ${REGION}"
echo ""

# Destroy server MIG
echo "Destroying server MIG..."
gcloud compute instance-groups managed delete "${CLUSTER_NAME}-server-mig" \
  --region="${REGION}" \
  --quiet || echo "Server MIG not found or already deleted"

# Destroy client MIGs (may be multiple for partitions)
echo "Destroying client MIGs..."
for mig in $(gcloud compute instance-groups managed list --filter="name~${CLUSTER_NAME}-clients-mig" --format="value(name)"); do
  echo "  Deleting: $mig"
  gcloud compute instance-groups managed delete "$mig" \
    --region="${REGION}" \
    --quiet || echo "  Client MIG $mig not found or already deleted"
done

# Destroy GPU client MIGs
echo "Destroying GPU client MIGs..."
for mig in $(gcloud compute instance-groups managed list --filter="name~${CLUSTER_NAME}-clients-gpu-mig" --format="value(name)"); do
  echo "  Deleting: $mig"
  gcloud compute instance-groups managed delete "$mig" \
    --region="${REGION}" \
    --quiet || echo "  GPU Client MIG $mig not found or already deleted"
done

echo ""
echo "✓ Managed instance groups destroyed."
