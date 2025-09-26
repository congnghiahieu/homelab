#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./manage_kind_cluster.sh start  <cluster-name>
#   ./manage_kind_cluster.sh stop   <cluster-name>
#   ./manage_kind_cluster.sh delete <cluster-name> [--purge-storage]
#
# Behavior:
#   - start/stop: docker start/stop node containers; PVC data is untouched.
#   - delete: kind delete cluster; keeps PVC data by default.
#             pass --purge-storage to also remove the host storage directory.

die() {
    echo "Error: $*" >&2
    exit 1
}

if [ $# -lt 2 ]; then
    echo "Usage: $0 <start|stop|delete> <cluster-name> [--purge-storage]" >&2
    exit 1
fi

cmd="$1"
cluster="$2"
shift 2 || true

CTX="kind-${cluster}"
HOST_STORAGE_DIR="${HOST_STORAGE_DIR:-$HOME/kind-storage/${cluster}}"

node_names() {
    # List all docker containers that belong to this kind cluster
    docker ps -a --format '{{.Names}}' | grep -E "^${cluster}-control-plane(-[0-9]+)?$" || true
}

case "$cmd" in
    start)
        names="$(node_names)"
        [ -n "$names" ] || die "No node containers found for cluster '${cluster}'. Is it created?"
        echo "$names" | xargs -r -n1 docker start
        echo "[INFO] Waiting for nodes to be Ready..."
        kubectl --context "${CTX}" wait node --all --for=condition=Ready --timeout=180s
        kubectl --context "${CTX}" get nodes -o wide
        ;;

    stop)
        names="$(node_names)"
        [ -n "$names" ] || die "No node containers found for cluster '${cluster}'."
        echo "$names" | xargs -r -n1 docker stop
        echo "[INFO] Cluster '${cluster}' stopped (state preserved)."
        ;;

    delete)
        purge="${1:-}"
        echo "[INFO] Deleting kind cluster: ${cluster}"
        kind delete cluster --name "${cluster}" || true
        if [ "${purge}" = "--purge-storage" ]; then
            echo "[INFO] Purging storage dir: ${HOST_STORAGE_DIR}"
            rm -rf --one-file-system "${HOST_STORAGE_DIR}"
        else
            echo "[INFO] PVC data preserved at: ${HOST_STORAGE_DIR}"
        fi
        ;;

    *)
        die "Unknown command '$cmd' (expected start|stop|delete)"
        ;;
esac
