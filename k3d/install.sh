#!/usr/bin/env bash
set -euo pipefail

# Installs: kubectl, k3d, kind, k9s
# - Temp directory for downloads; cleans up automatically
# - Arch auto-detect: amd64 / arm64
# - Latest versions by default; can pin with:
#   KUBECTL_VERSION=v1.31.1  KIND_VERSION=v0.23.0  K9S_VERSION=v0.32.5

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

arch="$(uname -m)"
case "$arch" in
    x86_64) bin_arch="amd64" ;;
    aarch64 | arm64) bin_arch="arm64" ;;
    *)
        echo "Unsupported architecture: $arch" >&2
        exit 1
        ;;
esac

# # --- kubectl (latest stable unless pinned) ---
# KUBECTL_VERSION="${KUBECTL_VERSION:-$(curl -fsSL https://dl.k8s.io/release/stable.txt)}"
# echo "[kubectl] Installing ${KUBECTL_VERSION} for ${bin_arch}"
# curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${bin_arch}/kubectl" -o "${tmpdir}/kubectl"
# curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${bin_arch}/kubectl.sha256" -o "${tmpdir}/kubectl.sha256"
# echo "$(cat "${tmpdir}/kubectl.sha256")  ${tmpdir}/kubectl" | sha256sum --check --status
# sudo install -o root -g root -m 0755 "${tmpdir}/kubectl" /usr/local/bin/kubectl
# kubectl version --client --output=yaml || true

# # --- k3d (latest via official installer) ---
# echo "[k3d] Installing latest"
# curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
# k3d version || true

# --- kind (latest unless pinned) ---
# If KIND_VERSION is set (e.g., v0.23.0), use sigs download URL; else use GitHub 'latest/download'.
if [ -n "${KIND_VERSION:-}" ]; then
    echo "[kind] Installing ${KIND_VERSION} for ${bin_arch}"
    src="https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${bin_arch}"
else
    echo "[kind] Installing latest (GitHub Releases) for ${bin_arch}"
    src="https://github.com/kubernetes-sigs/kind/releases/latest/download/kind-linux-${bin_arch}"
fi
curl -fsSL -o "${tmpdir}/kind" "${src}"
chmod +x "${tmpdir}/kind"
sudo install -o root -g root -m 0755 "${tmpdir}/kind" /usr/local/bin/kind
kind version || true

# --- k9s (latest via GitHub API unless pinned) ---
if [ -z "${K9S_VERSION:-}" ]; then
    echo "[k9s] Detecting latest version from GitHub API"
    K9S_VERSION="$(curl -fsSL https://api.github.com/repos/derailed/k9s/releases/latest \
        | sed -n 's/.*"tag_name":[[:space:]]*"\(v[^"]*\)".*/\1/p' | head -n1)"
    [ -n "$K9S_VERSION" ] || {
        echo "[k9s] Could not detect latest; set K9S_VERSION and re-run." >&2
        exit 1
    }
fi
echo "[k9s] Installing ${K9S_VERSION} for ${bin_arch}"
curl -fsSL -o "${tmpdir}/k9s.tar.gz" "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${bin_arch}.tar.gz"
tar -xzf "${tmpdir}/k9s.tar.gz" -C "${tmpdir}"
sudo install -o root -g root -m 0755 "${tmpdir}/k9s" "/usr/local/bin/k9s"
k9s version || true

echo "All done."
