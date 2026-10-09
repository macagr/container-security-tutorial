#!/usr/bin/env bash
# act5/02-kube-dementor.sh — turn the manual lessons into a repeatable audit.
# Terminal: host (A). Needs network (tool download) + the kind cluster from 01.
#
# kube-dementor lives in its OWN repository (separate from this lab).
# This script only installs and runs it, read-only, against the lab cluster.
#
# PIN POINT (fill in before the session):
KDM_REPO_URL="https://github.com/doguazot/kube-dementor"   # ← verify
KDM_VERSION=""                                             # ← pin a release tag
KDM_INSTALL_CMD=""                                        # ← upstream install command
#
# The framing: 45 minutes of manual work in acts 1-3 = one scanner run.
# The manual work is the WHY, the tool is the HOW OFTEN.

set -euo pipefail

hr()   { printf '\n\033[1m%s\033[0m\n' "----------------------------------------------------------------"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
say()  { printf '  %s\n' "$*"; }

if ! command -v kube-dementor >/dev/null 2>&1; then
    if [[ -z "$KDM_INSTALL_CMD" ]]; then
        hdr "INSTALL — pin point not filled yet"
        say "kube-dementor not found, and this script's install pin is empty."
        say "Fill KDM_VERSION and KDM_INSTALL_CMD at the top of this file from:"
        say "    $KDM_REPO_URL/releases"
        say "(detect arm64: this lab's reference VM is aarch64)"
        exit 1
    fi
    hdr "INSTALL (pinned $KDM_VERSION)"
    sh -c "$KDM_INSTALL_CMD"
fi
say "tool present: $(command -v kube-dementor)"

hdr "RUN — read-only against the lab cluster"
say "The default kubeconfig points at the kind cluster from 01-kind.sh."
say "Run the READ-ONLY stages only (the tutorial's safe-by-default rule):"
say "    kube-dementor discover        (collect: pods, nodes, RBAC, volumes)"
say "    kube-dementor scan            (rules: the act4 matrix, automated)"
say ""
say "The four pods from the manifests SHOULD each produce a finding:"
say "    privileged-pod   → node-exposure finding"
say "    hostpath-pod     → host-filesystem finding"
say "    sysadmin-cap-pod → dangerous-capability finding"
say "    hostpid-pod      → shared-namespace finding"
say "GRADE your beat-3 predictions against the actual output. Then map:"
say "every finding is an act4 row you can now explain AT THE KERNEL LEVEL."

hdr "AFTERMATH — what a reviewer does Monday morning"
cat <<'EOF'
  1. Run discovery + scan, READ-ONLY, against the inherited cluster
  2. Triage by the matrix: capability grants and masked-path gaps first
  3. Fix order: privileged:true > hostPath rw > SYS_ADMIN adds > hostPID
  4. Verify with Pod Security Admission labels (restricted on new namespaces)
  5. Re-scan: findings should close — evidence-based remediation, not vibes

  The one-sentence summary of the whole tutorial:
    you now know WHY each finding is a finding — the scanner just counts them.
EOF
