#!/usr/bin/env bash
# act3/remediations/binfmt_misc.sh — run INSIDE the jail, AFTER the escape.
# Removes the registration desk from YOUR mount namespace only.
set -euo pipefail
BINFMT_DIR=/proc/sys/fs/binfmt_misc
if ! grep -qs binfmt /proc/mounts; then
    echo "  binfmt_misc not mounted in this ns — already remediated (the container default!)"
else
    umount "$BINFMT_DIR" && echo "  APPLIED: unmounted binfmt_misc in this mount ns"
    echo "  register write now: $( (echo ':x:E::X::/bin/false:' > "$BINFMT_DIR/register" 2>&1 && echo "UNEXPECTEDLY WORKED") || echo "fails — desk is gone" )"
fi
cat <<'EOF'
  Kubernetes mapping:
    Normal containers never mount binfmt_misc — the remediation is the DEFAULT.
    It appears only in privileged pods or host-debug images: for those,
    privileged: false / maskedPaths / drop SYS_ADMIN restore the default state.
  Lesson: sometimes the remediation is "do not add the dangerous mount,"
  not "add a defense against it."
EOF
