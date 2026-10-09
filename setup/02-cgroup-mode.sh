#!/usr/bin/env bash
# setup/02-cgroup-mode.sh — read-only explainer for this (cgroup v2) branch.
# Terminal: host (A). No flags, no changes, no reboot: v2 is the default
# boot mode on modern distributions, so this branch needs no toggle.
#
# On the v1 branch this script also offered a grub toggle (--set-v1) so
# the release_agent technique could be seen working before its death.
# On THIS branch there is nothing to set — v2 is already your world if
# 00-check passed. This script remains as the reference for:
#   - which world you are in (and how to check)
#   - what that means for act1/03 and act3/04
#   - how a v1 machine would get here (and why it should not bother)

set -euo pipefail

current_mode() {
    case "$(stat -fc %T /sys/fs/cgroup)" in
        tmpfs)     echo "v1" ;;
        cgroup2fs) echo "v2" ;;
        *)         echo "unknown" ;;
    esac
}

MODE=$(current_mode)
echo "Current cgroup world: v${MODE#v}"
echo
case "$MODE" in
    v2)
        echo "  Matches this branch. What this means for the lab:"
        echo "    act1/03-cgroups.sh       creates cgroups with cgroup.subtree_control,"
        echo "                             cgroup.procs and memory.max (v2 files)"
        echo "    act3/04-release_agent.sh  demonstrates the technique's DEATH:"
        echo "                             the knob does not exist on v2 — and why"
        ;;
    v1)
        echo "  MISMATCH. This branch assumes v2. Two options:"
        echo "    (a) use the cgroup-v1 branch of this repository (recommended:"
        echo "        it shows the full success-then-death arc)"
        echo "    (b) remove the v1 flag from your kernel command line and reboot:"
        echo "        check /etc/default/grub for systemd.unified_cgroup_hierarchy=0"
        ;;
    *)
        echo "  cannot determine mode; check mounts"
        ;;
esac
echo
echo "The canonical check, used across the whole lab:"
echo "    stat -fc %T /sys/fs/cgroup    # tmpfs = v1, cgroup2fs = v2"
