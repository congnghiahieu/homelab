#!/usr/bin/env bash
set -euo pipefail

# Usage: ./create_kind_cluster.sh <cluster-name>
# Example: ./create_kind_cluster.sh hht-mano
if [ $# -lt 1 ]; then
  echo "Usage: $0 <cluster-name>" >&2
  exit 1
fi

CLUSTER_NAME="$1"
CTX="kind-${CLUSTER_NAME}"

# Host directory to persist PVC data (survives cluster delete/recreate)
HOST_STORAGE_DIR="${HOST_STORAGE_DIR:-$HOME/kind-storage/${CLUSTER_NAME}}"
mkdir -p "${HOST_STORAGE_DIR}"

cfg="$(mktemp)"
trap 'rm -f "${cfg}"' EXIT

cat > "${cfg}" << YAML
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
# Three control planes (HA). We'll remove the default taint post-create so they are schedulable.
nodes:
- role: control-plane
  extraMounts:
  - hostPath: ${HOST_STORAGE_DIR}
    containerPath: /var/local-path-provisioner
- role: control-plane
  extraMounts:
  - hostPath: ${HOST_STORAGE_DIR}
    containerPath: /var/local-path-provisioner
- role: control-plane
  extraMounts:
  - hostPath: ${HOST_STORAGE_DIR}
    containerPath: /var/local-path-provisioner
YAML

echo "[INFO] Creating kind cluster: ${CLUSTER_NAME}"
kind create cluster --name "${CLUSTER_NAME}" --config "${cfg}"

echo "[INFO] Waiting for nodes to be Ready..."
kubectl --context "${CTX}" wait node --all --for=condition=Ready --timeout=180s

echo "[INFO] Making control-planes schedulable (remove taint)..."
kubectl --context "${CTX}" taint nodes -l node-role.kubernetes.io/control-plane \
  node-role.kubernetes.io/control-plane- || true

echo "[INFO] Installing local-path-provisioner (default StorageClass)..."
kubectl --context "${CTX}" apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# Point the provisioner to our mounted host path on every node
kubectl --context "${CTX}" -n local-path-storage patch configmap local-path-config \
  --type merge \
  -p '{"data":{"config.json":"{\"nodePathMap\":[{\"node\":\"DEFAULT_PATH_FOR_NON_LISTED_NODES\",\"paths\":[\"/var/local-path-provisioner\"]}]}"}}'

kubectl --context "${CTX}" annotate sc local-path storageclass.kubernetes.io/is-default-class="true" --overwrite

echo "[INFO] Cluster created. Verifying:"
kubectl --context "${CTX}" get nodes -o wide
kubectl --context "${CTX}" get storageclass
echo "[INFO] PVCs will persist under: ${HOST_STORAGE_DIR}"
