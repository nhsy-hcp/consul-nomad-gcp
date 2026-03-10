#!/bin/bash
set -euo pipefail

# Destroy load balancers and related resources via gcloud
# This script destroys forwarding rules, target proxies, backend services, and health checks

echo "Destroying load balancers and related resources..."

# Get cluster name and region from Terraform outputs or use defaults
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "dc1-hcp")
REGION=$(terraform output -raw gcp_region 2>/dev/null || echo "europe-west1")

echo "Cluster: ${CLUSTER_NAME}"
echo "Region: ${REGION}"
echo ""

# Destroy regional forwarding rules (client ingress)
echo "Destroying regional forwarding rules..."
for rule in $(gcloud compute forwarding-rules list --filter="name~${CLUSTER_NAME}-clients-lb" --format="value(name)"); do
  echo "  Deleting: $rule"
  gcloud compute forwarding-rules delete "$rule" \
    --region="${REGION}" \
    --quiet || echo "  Forwarding rule $rule not found or already deleted"
done

# Destroy global forwarding rules (Nomad/Consul)
echo "Destroying global forwarding rules..."
gcloud compute forwarding-rules delete "${CLUSTER_NAME}-forwarding-rule" \
  --global \
  --quiet || echo "  Nomad forwarding rule not found or already deleted"

gcloud compute forwarding-rules delete "${CLUSTER_NAME}-consul-forwarding-rule" \
  --global \
  --quiet || echo "  Consul forwarding rule not found or already deleted"

# Destroy target proxies
echo "Destroying target HTTPS proxies..."
gcloud compute target-https-proxies delete "${CLUSTER_NAME}-https-proxy" \
  --quiet || echo "  Nomad HTTPS proxy not found or already deleted"

gcloud compute target-https-proxies delete "${CLUSTER_NAME}-consul-https-proxy" \
  --quiet || echo "  Consul HTTPS proxy not found or already deleted"

# Destroy URL maps
echo "Destroying URL maps..."
gcloud compute url-maps delete "${CLUSTER_NAME}-nomad-url-map" \
  --quiet || echo "  Nomad URL map not found or already deleted"

gcloud compute url-maps delete "${CLUSTER_NAME}-consul-url-map" \
  --quiet || echo "  Consul URL map not found or already deleted"

# Destroy global backend services
echo "Destroying global backend services..."
for backend in $(gcloud compute backend-services list --filter="name~${CLUSTER_NAME}" --format="value(name)"); do
  echo "  Deleting: $backend"
  gcloud compute backend-services delete "$backend" \
    --global \
    --quiet || echo "  Backend service $backend not found or already deleted"
done

# Destroy regional backend services
echo "Destroying regional backend services..."
for backend in $(gcloud compute region-backend-services list --filter="name~${CLUSTER_NAME}" --format="value(name)"); do
  echo "  Deleting: $backend"
  gcloud compute region-backend-services delete "$backend" \
    --region="${REGION}" \
    --quiet || echo "  Regional backend service $backend not found or already deleted"
done

# Destroy global health checks
echo "Destroying global health checks..."
for hc in $(gcloud compute health-checks list --filter="name~${CLUSTER_NAME}" --format="value(name)"); do
  echo "  Deleting: $hc"
  gcloud compute health-checks delete "$hc" \
    --quiet || echo "  Health check $hc not found or already deleted"
done

# Destroy regional health checks
echo "Destroying regional health checks..."
for hc in $(gcloud compute region-health-checks list --filter="name~${CLUSTER_NAME}" --format="value(name)"); do
  echo "  Deleting: $hc"
  gcloud compute region-health-checks delete "$hc" \
    --region="${REGION}" \
    --quiet || echo "  Regional health check $hc not found or already deleted"
done

echo ""
echo "✓ Load balancers and related resources destroyed."
