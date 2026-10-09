#!/usr/bin/env bash
# setup/02-cgroup-mode.sh — inspect or change the machine's cgroup world.
# Terminal: host (A). Read-only by default; --set-v1 / --set-v2 need sudo + reboot.
#
# WHY THIS EXISTS (the core design decision of the lab):
#   release_agent is a cgroup v1 feature. Modern Ubuntu boots unified cgroup v2
#   where the file simply does not exist. Act 3 wants BOTH behaviors:
#     - success on v1  (attendees see the escape work)
#     - death on v2    (the modern lesson — and timely: k8s is migrating to v2)
#   Since the mode is chosen at BOOT via the kernel cmdline, switching is a
#   grub edit + reboot. This script does that safely and reversibly.
#
# Usage:
#   setup/02-cgroup-mode.sh           # read-only: show current mode + explanation
#   sudo setup/02-cgroup-mode.sh --set-v1   # boot cgroup v1 next reboot
#   sudo setup/02-cgroup-mode.sh --set-v2   # restore unified v2 (default)
#
# The canonical check attendees memorize (used across the whole lab):
#   stat -fc %T /sys/fs/cgroup    # tmpfs = v1, cgroup2fs = v2

set -euo pipefail

GRUB_FILE=/etc/default/grub
FLAG="systemd.unified_cgroup_hierarchy=0"
BACKUP="${GRUB_FILE}.lab-backup"

current_mode() {
    case "$(stat -fc %T /sys/fs/cgroup)" in
        tmpfs)     echo "v1" ;;
        cgroup2fs) echo "v2" ;;
        *)         echo "unknown" ;;
    esac
}

show_status() {
    MODE=$(current_mode)
    echo "Current cgroup world: v${MODE#v}"
    case "$MODE" in
        v1) echo "  release_agent WILL work (act3/04 beat 2 succeeds)" ;;
        v2) echo "  release_agent WILL FAIL — no release_agent file exists on v2" ;;
        *)  echo "  cannot determine; check mounts" ;;
    esac
    if grep -q -- "$FLAG" "$GRUB_FILE" 2>/dev/null; then
        echo "  grub config: v1 flag PRESENT in $GRUB_FILE (takes effect at boot)"
    else
        echo "  grub config: no v1 flag (default = unified v2)"
    fi
}

apply_flag() {   # $1 = add|remove
    local action="$1"
    [[ $EUID -eq 0 ]] || { echo "run with sudo for --set-v1/--set-v2"; exit 1; }
    [[ -f "$BACKUP" ]] || cp "$GRUB_FILE" "$BACKUP"   # one-time backup, never overwritten

    if [[ "$action" == add ]]; then
        if grep -q -- "$FLAG" "$GRUB_FILE"; then
            echo "v1 flag already present — nothing to do (reboot to apply if mode shows v2)"
        else
            # append to GRUB_CMDLINE_LINUX_DEFAULT, preserving existing content
            sed -i "s/^\(GRUB_CMDLINE_LINUX_DEFAULT=\".*\)\"/\1 $FLAG\"/" "$GRUB_FILE"
            grep -q -- "$FLAG" "$GRUB_FILE" || {
                echo "failed to inject flag; restore with: cp $BACKUP $GRUB_FILE"; exit 1; }
            echo "cgroup v1 flag added to $GRUB_FILE (backup at $BACKUP)"
        fi
    else
        if grep -q -- "$FLAG" "$GRUB_FILE"; then
            sed -i "s/ $FLAG//" "$GRUB_FILE"
            echo "cgroup v1 flag removed — next boot is unified v2 again"
        else
            echo "no v1 flag present — already v2-configured"
        fi
    fi
    update-grub
    echo
    echo "  REBOOT REQUIRED: the mode is chosen at boot."
    echo "  After reboot, verify with:  stat -fc %T /sys/fs/cgroup   (want: tmpfs)"
    echo "  To go back to v2 later:      sudo $0 --set-v2"
}

case "${1:-}" in
    --set-v1) apply_flag add ;;
    --set-v2) apply_flag remove ;;
    "")       show_status ;;
    *) echo "usage: $0 [--set-v1|--set-v2]"; exit 2 ;;
esac
