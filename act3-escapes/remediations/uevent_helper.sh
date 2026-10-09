#!/usr/bin/env bash
# act3/remediations/uevent_helper.sh — run INSIDE the jail, AFTER the escape.
set -euo pipefail
KNOB=/sys/kernel/uevent_helper
[[ -e "$KNOB" ]] || { echo "  knob absent on this kernel (CONFIG_UEVENT_HELPER off) — already remediated at build level"; exit 0; }
echo "  BEFORE: $(cat $KNOB)"
mount --bind /dev/null "$KNOB"
echo "  APPLIED: /dev/null bind — writes succeed into the void"
echo "  AFTER: knob value now: '$(cat $KNOB)'"
cat <<'EOF'
  Kubernetes mapping:
    maskedPaths: [/sys/kernel/uevent_helper]
    Do not mount host /sys rw in pods (privileged: false already prevents it)
  Deeper layer: kernels built without CONFIG_UEVENT_HELPER lack the knob entirely.
EOF
