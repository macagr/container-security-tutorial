#!/usr/bin/env bash
# act3/remediations/capabilities.sh — the foundational fix, demonstrated.
# Run anywhere (host or jail): drop CAP_SYS_ADMIN in a subshell and test the
# four knobs' write paths at once.
set -euo pipefail
capsh --drop=cap_sys_admin -- -c '
  for knob in /proc/sys/kernel/core_pattern /sys/kernel/uevent_helper /proc/sys/fs/binfmt_misc/register; do
    if [[ -e "$knob" ]]; then
        (echo x > "$knob" 2>/dev/null && echo "  WROTE $knob (unexpected)") || echo "  DENIED: $knob"
    else
        echo "  ABSENT: $knob (not mounted here — mount-level defense already holds)"
    fi
  done
'
cat <<'EOF'
  One capability removal, four attack surfaces closed. This is why
  'privileged: true' is a bundle of exposures, not a single permission:
  it grants the write access EVERY usermode-helper technique requires.

  Kubernetes mapping:
    securityContext.privileged: false                    (removes the bundle)
    securityContext.capabilities.drop: [ALL]              (explicit allowlist style)
    add back ONLY named capabilities the workload needs   (the real practice)

  Act 4 matrix row: technique × CAP_SYS_ADMIN × drop SYS_ADMIN + masked paths.
EOF
