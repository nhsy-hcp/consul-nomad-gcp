#!/bin/bash
set -euo pipefail

# Check server logs via gcloud SSH and IAP
# This script connects to server instances and displays cloud-init and service logs

# Get cluster name and region from Terraform outputs or use defaults
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "dc1-hcp")
REGION=$(terraform output -raw gcp_region 2>/dev/null || echo "europe-west1")

echo "Cluster: ${CLUSTER_NAME}"
echo "Region: ${REGION}"
echo ""

# Check if a specific server was provided as argument
if [ $# -eq 1 ]; then
  SERVER_NAME="$1"
  echo "Checking logs for specific server: ${SERVER_NAME}"

  # Get the zone for this instance
  ZONE=$(gcloud compute instances list --filter="name=${SERVER_NAME}" --format="value(zone)" | head -1)

  if [ -z "$ZONE" ]; then
    echo "Error: Server ${SERVER_NAME} not found"
    exit 1
  fi

  echo "Connecting to ${SERVER_NAME} in zone ${ZONE}..."
  echo ""

  # Connect and show logs
  gcloud compute ssh "${SERVER_NAME}" \
    --zone="${ZONE}" \
    --tunnel-through-iap \
    --command="echo '=== Startup Script Logs (last 100 lines) ===' && \
               sudo journalctl -u google-startup-scripts.service --no-pager -n 100 && \
               echo '' && \
               echo '=== Metadata Script Logs ===' && \
               sudo cat /var/log/syslog | grep -i 'startup-script' | tail -50 && \
               echo '' && \
               echo '=== Consul Status ===' && \
               sudo systemctl status consul --no-pager -l && \
               echo '' && \
               echo '=== Nomad Status ===' && \
               sudo systemctl status nomad --no-pager -l"
else
  # List all servers and check their cloud-init status
  echo "Listing all server instances..."
  gcloud compute instances list --filter="name~${CLUSTER_NAME}-server" --format="table(name,zone,status)"
  echo ""

  echo "Checking cloud-init status on all servers..."
  echo ""

  # Check startup script status on all servers
  while IFS=$'\t' read -r name zone; do
    echo "=== ${name} (${zone}) ==="
    gcloud compute ssh "${name}" \
      --zone="${zone}" \
      --tunnel-through-iap \
      --command="sudo systemctl status google-startup-scripts.service --no-pager | head -20" 2>&1 || echo "  Failed to connect"
    echo ""
  done < <(gcloud compute instances list --filter="name~${CLUSTER_NAME}-server" --format="value(name,zone)")

  echo ""
  echo "To check detailed logs for a specific server, run:"
  echo "  $0 <server-name>"
  echo ""
  echo "To get an interactive shell on a server, run:"
  echo "  gcloud compute ssh <server-name> --zone=<zone> --tunnel-through-iap"
fi
