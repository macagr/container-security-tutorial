#!/usr/bin/env bash
# setup/01-packages.sh — install lab tooling. Terminal: host (A). Needs network.
#
# Reference machine: Ubuntu 24.04.5 LTS arm64 (Parallels on Apple Silicon).
# NOTE for amd64 attendees: everything below except the kind/kubectl downloads
# is arch-independent; those two downloads have arch detection built in.
#
# Everything is guarded per-package: re-running skips what is already there.
# Only act5 needs docker/kind/kubectl; acts 1-4 need the small utilities.

set -euo pipefail

# --- helpers -------------------------------------------------------------
have()   { command -v "$1" >/dev/null 2>&1; }
pkg_ok() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"; }

apt_install() {
    local todo=()
    for p in "$@"; do pkg_ok "$p" || todo+=("$p"); done
    if [[ ${#todo[@]} -gt 0 ]]; then
        echo "installing: ${todo[*]}"
        sudo apt-get update -qq
        sudo apt-get install -y -qq "${todo[@]}"
    else
        echo "already installed: $*"
    fi
}

hdr() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }

# --- 1. lab core utilities -------------------------------------------------
hdr "Core lab utilities"
# jq          : read/write JSON (seccomp profiles, kube-dementor output)
# strace      : watch the syscalls behind every beat (EPERM moments in act1)
# libcap2-bin : capsh — decode/modify capability sets (act1/04, act4 matrix)
# util-linux  : unshare, nsenter, mount (preinstalled on 24.04, listed anyway)
# busybox-static : the minimal rootfs for act1/06 pivot_root
# bpftrace    : optional live tracing (nice for act2, skippable on slow wifi)
apt_install jq strace libcap2-bin util-linux busybox-static
have bpftrace || sudo apt-get install -y -qq bpftrace || \
    echo "  (bpftrace optional — skipping, not fatal)"

# --- 2. AppArmor tooling (act3 remediation beats) ---------------------------
hdr "AppArmor"
apt_install apparmor apparmor-utils

# --- 3. container runtime + kind + kubectl (act5 only) ----------------------
hdr "Kubernetes tooling (act5)"
if have docker; then
    echo "docker already present: $(docker --version)"
else
    apt_install docker.io
    echo "  adding $USER to docker group (log out/in once to take effect, or use sudo)"
    sudo usermod -aG docker "$USER" 2>/dev/null || true
fi

ARCH=$(uname -m)
case "$ARCH" in
    aarch64) KIND_ARCH=arm64; KUBECTL_ARCH=arm64 ;;
    x86_64)  KIND_ARCH=amd64; KUBECTL_ARCH=amd64 ;;
    *) echo "unexpected arch $ARCH"; exit 1 ;;
esac

if ! have kind; then
    # snap 'kind' is amd64-only on arm; use the official release binary instead
    KIND_VER="v0.29.0"   # pin: update when the lab is re-tested
    sudo curl -fsSL -o /usr/local/bin/kind \
        "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VER}/kind-linux-${KIND_ARCH}"
    sudo chmod +x /usr/local/bin/kind
    echo "kind installed: $(kind version)"
else
    echo "kind already present: $(kind version)"
fi

if ! have kubectl; then
    K8S_VER="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
    sudo curl -fsSL -o /usr/local/bin/kubectl \
        "https://dl.k8s.io/release/${K8S_VER}/bin/linux/${KUBECTL_ARCH}/kubectl"
    sudo chmod +x /usr/local/bin/kubectl
    echo "kubectl installed: $(kubectl version --client 2>/dev/null | head -1)"
else
    echo "kubectl already present: $(kubectl version --client 2>/dev/null | head -1)"
fi

# --- summary -----------------------------------------------------------------
hdr "Versions (pin these in the README when the lab is finalized)"
for c in unshare nsenter capsh strace jq busybox; do
    printf '  %-10s %s\n' "$c" "$(command -v $c || echo MISSING)"
done
docker --version 2>/dev/null || echo "  docker      MISSING"
kind version 2>/dev/null || echo "  kind        MISSING"
kubectl version --client 2>/dev/null | head -1 || echo "  kubectl     MISSING"

cat <<'EOF'

  Next steps:
    1. setup/02-cgroup-mode.sh           (optional --set-v1 for release_agent, ONE reboot)
    2. act1-build-the-jail/01-namespaces.sh
EOF
