#!/usr/bin/env bash
# act2/01-usermode-helpers.sh — the kernel's escape hatches.
# Terminal: lab (B), Terminal A optional. Read-only: we LOOK, we do not fire.
# (act3 fires them, from inside a privileged cage, with cleanup traps.)
#
# Beats:
#   1. The concept: call_usermodehelper — the kernel executing programs
#   2. The contract: REAL root, INIT mount/pid namespaces — not yours
#   3. The four knobs on this machine: defaults, locations, triggers
#   4. The control question (the attack recipe's first half)
#
# CLEANUP: nothing to clean — read-only throughout.

set -euo pipefail

hr()   { printf '\n\033[1m%s\033[0m\n' "----------------------------------------------------------------"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
say()  { printf '  %s\n' "$*"; }
pause(){ printf '\n  \033[2m[press Enter for the next beat]\033[0m'; read -r; }

KCONF=/boot/config-$(uname -r)

# --------------------------------------------------------------------------
hdr "BEAT 1 — the kernel sometimes runs programs. Here is the call."
hr
say "Some kernel events are handled by... asking userspace to run a program."
say "The entry point is one function: call_usermodehelper(exec, argv, env)."
say "Kernel threads that use it include:"
say "    - core dumps piped to a handler        (core_pattern)"
say "    - hotplug / device events               (uevent_helper)"
say "    - executing unknown binary formats      (binfmt_misc interpreters)"
say "    - cgroup cleanup callbacks               (release_agent, v1 only)"
say ""
say "None of these care that a container exists. The callback is a KERNEL"
say "decision made BEFORE namespace checks apply to the CHILD it spawns."
pause

# --------------------------------------------------------------------------
hdr "BEAT 2 — the contract: where does that program run?"
hr
say "Every helper runs with:"
say "    uid 0      — REAL root, in the INIT user namespace     (no userns wall)"
say "    init mount namespace — the HOST's view of the filesystem, not yours"
say "    init pid namespace  — full process table"
say ""
say "Act 1 built one sentence: 'namespaces isolate you, not the kernel.'"
say "This is that sentence, weaponized: the kernel's CALLBACKS obey the"
say "init namespaces — and if a container can point the callback at a file"
say "it controls, the callback executes ITS file as ROOT in the HOST's world."
say ""
say "The two-part attack recipe (memorize for act 3):"
say "    (1) WHO can WRITE the knob?      (capabilities / mounts — act1/04)"
say "    (2) WHAT PATH does the knob run — resolved WHERE?  (init mount ns —"
say "        act2/02 is entirely about making this concrete)"
pause

# --------------------------------------------------------------------------
hdr "BEAT 3 — the four knobs, on this machine, right now"
hr
say "Run (host or any shell — all read-only):"
say "    cat /proc/sys/kernel/core_pattern      (default: 'core' — a FILENAME,"
say "                                          but if it starts with '|' the"
say "                                          kernel runs it as a PROGRAM)"
say "    cat /sys/kernel/uevent_helper          (default: '' — disabled)"
say "    ls /proc/sys/fs/binfmt_misc/           (a registration desk)"
say "    ls /sys/fs/cgroup/ | grep -E 'release_agent|notify_on_release'"
say ""
if [[ -f "$KCONF" ]]; then
    say "Kernel build flags on this machine ($(uname -r)):"
    say "    grep -E 'UEVENT_HELPER|BINFMT_MISC|COREDUMP' $KCONF"
    grep -E 'CONFIG_UEVENT_HELPER|CONFIG_BINFMT_MISC|CONFIG_COREDUMP' "$KCONF" | sed 's/^/        /'
    say ""
    say "CONFIG_UEVENT_HELPER=y means the uevent knob is LIVE on this kernel."
    say "If it says '# CONFIG_UEVENT_HELPER is not set', act3/02's escape is"
    say "impossible by BUILD — a remediation at the kernel-config level. Same"
    say "lesson, different layer: defenses exist at every layer of the stack."
fi
pause

# --------------------------------------------------------------------------
hdr "BEAT 4 — map each knob to its trigger and its prerequisite"
hr
say "Fill this table in YOUR notes now (answers verified in act3):"
cat <<'EOF'
        knob                trigger event                write prereq
        core_pattern        a process dumps core         CAP_SYS_ADMIN + rw /proc/sys
        uevent_helper       a kernel uevent fires        CAP_SYS_ADMIN + rw /sys
        binfmt_misc         exec of unknown format       register file writable
        release_agent       a v1 cgroup becomes empty   CAP_SYS_ADMIN + rw cgroup v1
EOF
say ""
say "Notice every row of the write-prereq column is an act1/04 capability"
say "answer. You already did this analysis without noticing."
pause

# --------------------------------------------------------------------------
hdr "CHECK QUESTIONS (act2/01)"
cat <<'EOF'
  1. When the kernel runs a core_pattern program, in which mount namespace
     does the path resolve? Which user namespace holds the resulting uid?
  2. Why is '|' the most dangerous character in /proc/sys/kernel/core_pattern?
  3. Name one knob from beat 3 that can be disabled at KERNEL BUILD time
     (kernel-config as remediation layer).

  PREDICTION for act2/02: you are in a container (mount ns + overlay rootfs,
     like act1/06). You write /payload.sh through the MERGED view. Give the
     exact string the knob needs to run it — remember: resolution happens
     in the HOST's mount namespace.

  Next: act2-escape-hatches/02-path-resolution.sh
EOF
