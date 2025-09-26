#!/usr/bin/env bash
set -euo pipefail

# --- Usage ---
# ./create_k3d_cluster.sh <cluster-name>
# Example: ./create_k3d_cluster.sh lab3

if [ $# -lt 1 ]; then
    echo "Usage: $0 <cluster-name>"
    exit 1
fi

CLUSTER_NAME="$1"
HOST_STORAGE_DIR="${HOST_STORAGE_DIR:-$HOME/k3d-storage/${CLUSTER_NAME}}" # Persist volumes
mkdir -p "${HOST_STORAGE_DIR}"

echo "[INFO] Creating k3d cluster: ${CLUSTER_NAME}"
k3d cluster create "${CLUSTER_NAME}" \
    --servers 3 \
    --agents 0 \
    --wait \
    --timeout 120s \
    --volume "${HOST_STORAGE_DIR}:/var/lib/rancher/k3s/storage@all"

echo "[INFO] Cluster created. Verifying nodes..."
kubectl --context "k3d-${CLUSTER_NAME}" get nodes -o wide
