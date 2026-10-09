#!/usr/bin/env bash
# act3/remediations/core_pattern.sh — run INSIDE the privileged jail, AFTER the escape.
# Applies runc's maskedPaths mechanism to core_pattern, proves the knob is dead.
set -euo pipefail
KNOB=/proc/sys/kernel/core_pattern
echo "  BEFORE: $(cat $KNOB)"
mount --bind /dev/null "$KNOB"
echo "  APPLIED: bind-mounted /dev/null over the knob (what maskedPaths does)"
echo "  AFTER write test: $( (echo '|x' > "$KNOB" 2>&1 && echo "write went to /dev/null — knob value now: $(cat "$KNOB")") || true )"
cat <<'EOF'
  Kubernetes mapping:
    securityContext.maskedPaths: [/proc/sys/kernel/core_pattern]  ← this exact bind
    securityContext.readOnlyRootFilesystem / ro /proc/sys         ← alternative flavor
    securityContext.privileged: false                              ← removes the CAP too
  Pod Security Standards: 'restricted' masks this knob by default.
EOF
