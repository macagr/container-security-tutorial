#!/usr/bin/env bash
# setup/00-check.sh — prereq audit. Run FIRST. Terminal: host (A). Read-only.
#
# What you should see at the end: a checklist of what works on this machine
# and what needs fixing before the lab (cgroup mode, AppArmor, userns, disk).
#
# Reference machine this lab was built and tested on:
#   Ubuntu 24.04.5 LTS, kernel 7.0.0-31-generic, Parallels VM.
# Escape behavior varies across kernels; if your kernel differs a lot,
# expect small differences and check the repo's kernel notes.

set -euo pipefail

# --- helpers -------------------------------------------------------------
PASS=0; WARN=0; FAIL=0
ok()   { printf '  \033[32m[ OK ]\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
warn() { printf '  \033[33m[WARN]\033[0m %s\n' "$*"; WARN=$((WARN+1)); }
bad()  { printf '  \033[31m[FAIL]\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
note() { printf '        %s\n' "$*"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }

# --- 1. platform ---------------------------------------------------------
hdr "Platform"
KERNEL=$(uname -r)
OS=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
VIRT=$(systemd-detect-virt 2>/dev/null || echo "unknown")
ok "kernel: $KERNEL"
note "distro:  $OS"
note "virt:    $VIRT ($(hostnamectl 2>/dev/null | grep -i 'Chassis' | sed 's/.*: *//' || echo '?'))"

# --- 2. privileges -------------------------------------------------------
hdr "Privileges"
if [[ $EUID -eq 0 ]]; then
    ok "running as root"
elif sudo -n true 2>/dev/null || sudo true >/dev/null 2>&1; then
    ok "sudo available (lab needs root for mounts and cgroup writes)"
else
    bad "no root/sudo — the lab CANNOT run (mounts, /proc/sys, cgroups)"
fi

# --- 3. cgroup world -----------------------------------------------------
# The core design decision of the lab (see setup/02-cgroup-mode.sh):
#   tmpfs     = v1 -> release_agent escape WORKS
#   cgroup2fs = v2 -> release_agent escape FAILS (the lesson, but we want
#              attendees to see it succeed on v1 first: run 02-cgroup-mode.sh)
hdr "Cgroup world"
CG_TYPE=$(stat -fc %T /sys/fs/cgroup)
case "$CG_TYPE" in
    tmpfs)
        ok "cgroup v1 hierarchy mounted — release_agent will work"
        note "you can still demo the v2 failure: see act3/04-release_agent.sh"
        ;;
    cgroup2fs)
        warn "unified cgroup v2 (the modern default) — release_agent will FAIL"
        note "expected on current Ubuntu; to see the v1 success first, run:"
        note "    sudo setup/02-cgroup-mode.sh --set-v1   (requires ONE reboot)"
        note "if you prefer to stay on v2, act3/04 will demo the failure only"
        ;;
    *)
        bad "unrecognized mount type on /sys/fs/cgroup: $CG_TYPE"
        ;;
esac

# --- 4. user namespaces --------------------------------------------------
hdr "User namespaces"
MAX_USERNS=$(cat /proc/sys/user/max_user_namespaces 2>/dev/null || echo 0)
if [[ "$MAX_USERNS" -gt 0 ]]; then
    ok "max_user_namespaces = $MAX_USERNS (unprivileged userns available)"
else
    bad "user namespaces disabled (max_user_namespaces = 0)"
    note "fix: sysctl -w user.max_user_namespaces=15000"
fi
# Ubuntu-specific toggle; absent on other distros
if sysctl kernel.unprivileged_userns_clone >/dev/null 2>&1; then
    CLONE=$(sysctl -n kernel.unprivileged_userns_clone)
    if [[ "$CLONE" = "1" ]]; then ok "kernel.unprivileged_userns_clone = 1"
    else warn "kernel.unprivileged_userns_clone = 0 — act1/02 userns beats will need root"; fi
fi

# --- 5. AppArmor (act3 remediation) ---------------------------------------
hdr "AppArmor"
# detect via /sys, NOT aa-status — aa-status requires root and this script
# must work unprivileged (an attendee's pre-flight shouldn't need a password)
if [[ -d /sys/module/apparmor ]]; then
    if grep -q '^Y' /sys/module/apparmor/parameters/enabled 2>/dev/null; then
        ok "AppArmor module loaded and enabled"
    else
        warn "AppArmor module present but not enabled"
    fi
else
    warn "AppArmor not detected — the AppArmor remediation beat will be skipped"
    note "fix: apt-get install -y apparmor apparmor-utils"
fi

# --- 6. overlayfs (act1/05 + the act2 bridge) -----------------------------
hdr "Filesystems"
if grep -qw overlay /proc/filesystems; then
    ok "overlayfs available in kernel"
else
    bad "overlayfs not available — the lab rootfs CANNOT be built"
fi
DISK_AVAIL=$(df -BG / | tail -1 | awk '{print $4}' | tr -d 'G')
if [[ "$DISK_AVAIL" -ge 10 ]]; then
    ok "disk: ${DISK_AVAIL}G free (need ~10G; act5/kind adds a few GB)"
else
    warn "disk: only ${DISK_AVAIL}G free — enough for acts 1-4, act5/kind may be tight"
fi

# --- 7. the knobs we will abuse (informational) ---------------------------
hdr "Escape knobs visible on this machine"
for knob in /proc/sys/kernel/core_pattern \
            /sys/kernel/uevent_helper \
            /sys/fs/cgroup/cgroup.procs ; do
    if [[ -e "$knob" ]]; then ok "present: $knob"; else warn "missing: $knob"; fi
done
# binfmt_misc usually needs an explicit mount — we do that in act3
if [[ -d /proc/sys/fs/binfmt_misc ]] && grep -q binfmt /proc/mounts; then
    ok "binfmt_misc already mounted"
else
    note "binfmt_misc not mounted yet (normal — act3/03 mounts it)"
fi

# --- summary --------------------------------------------------------------
hdr "Summary"
printf '  %d ok, %d warnings, %d failures\n' "$PASS" "$WARN" "$FAIL"

cat <<'EOF'

  CHECK QUESTION (answer before moving on):
    Which cgroup world is this machine in, and which release_agent
    behavior does that predict: the v1 success or the v2 failure?

  Next steps:
    1. setup/01-packages.sh          (install lab tooling)
    2. setup/02-cgroup-mode.sh       (optional --set-v1, one reboot)
    3. act1-build-the-jail/01-namespaces.sh
EOF

# hard fails block the lab; warnings are decisions
[[ "$FAIL" -eq 0 ]] || exit 1
exit 0
