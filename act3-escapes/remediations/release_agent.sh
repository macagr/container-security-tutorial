#!/usr/bin/env bash
# act3/remediations/release_agent.sh — run INSIDE the jail, AFTER the escape.
# Flavor: drop the one capability the technique needs, then re-attempt.
set -euo pipefail
echo "  Attempting to mount a fresh v1 hierarchy WITHOUT CAP_SYS_ADMIN:"
if capsh --drop=cap_sys_admin -- -c 'mkdir -p /tmp/rem-cg && mount -t cgroup -o rdma cgroup /tmp/rem-cg' 2>&1; then
    echo "  UNEXPECTED: mount worked — investigate why SYS_ADMIN is still available"
else
    echo "  → Operation not permitted. No CAP_SYS_ADMIN = no hierarchy = no release_agent."
fi
cat <<'EOF'
  Kubernetes mapping (layered, all apply at once in a normal pod):
    securityContext.privileged: false          ← no CAP_SYS_ADMIN (this demo)
    securityContext.capabilities.drop: [ALL]     ← the explicit form
    default mounts: no cgroup filesystem rw in the cage
    cgroup v2 (modern clusters): the knob does not exist at all — beat 3's death
  The technique's prereq chain: mount hierarchy → write release_agent →
  arm notify_on_release → leave. Dropping ONE capability kills step 1.
EOF
