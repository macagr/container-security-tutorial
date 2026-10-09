#!/usr/bin/env bash
# act3/04-release_agent.sh — escape 4 of 4: the one the kernel already killed.
# Terminal: lab (B) + host (A). Uses sudo. DISPOSABLE LAB VM ONLY.
# This is the CGROUP V2 branch: your machine boots unified hierarchy, so the
# technique is DEAD here. This script proves the death, then tells you the
# v1 story as history — often the strongest remediation lesson in the lab:
# the kernel team classified a whole callback as a bug class and deleted it.
#
# Beats:
#   1. PREDICT (before everything): does release_agent exist on this kernel?
#   2. THE HUNT: prove the absence, on your machine, live
#   3. THE HISTORY: how the v1 escape worked, and why it died
#   4. THE LESSON: what v2 kept, what it removed, and what it means for
#      the other three techniques (which still work — act3/01..03 proved it)
#
# CLEANUP: nothing to clean — this script changes nothing on the machine.

set -euo pipefail

hr()   { printf '\n\033[1m%s\033[0m\n' "----------------------------------------------------------------"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
say()  { printf '  %s\n' "$*"; }
pause(){ printf '\n  \033[2m[press Enter for the next beat]\033[0m'; read -r; }

# --------------------------------------------------------------------------
hdr "BEAT 1 — PREDICT: does the knob exist here?"
hr
say "From act2/01 you know the four knobs. Three of them are live on this"
say "machine — you exploited them in act3/01..03. Before we check anything,"
say "commit in writing:"
say "    On this kernel, release_agent: EXISTS / ABSENT?"
say "    If absent: BLOCKED (defendable) or DELETED (redesigned away)?"
pause

# --------------------------------------------------------------------------
hdr "BEAT 2 — THE HUNT: prove the absence on your machine"
hr
say "Run (host or jail — this beat is read-only and version-independent):"
say "    stat -fc %T /sys/fs/cgroup            (cgroup2fs — the unified world)"
say "    find /sys/fs/cgroup -maxdepth 3 -name 'release_agent'"
say "    find /sys/fs/cgroup -maxdepth 3 -name 'notify_on_release'"
say "    (both: no output. The files are not hidden — they are GONE.)"
say ""
say "For completeness, mount a fresh v2 hierarchy and hunt there too:"
say "    sudo mkdir -p /tmp/cg2-check && sudo mount -t cgroup2 none /tmp/cg2-check"
say "    ls /tmp/cg2-check | head -20"
say "    ls /tmp/cg2-check | grep -c release_agent    (zero)"
say "    sudo umount /tmp/cg2-check && sudo rmdir /tmp/cg2-check"
say ""
say "Contrast — this file DID exist in the v1 world, at the root of every"
say "hierarchy, next to files whose names you now know (tasks, memory.limit_"
say "in_bytes). The cgroup v1 lab branch lets you fire it for real; here we"
say "study a corpse. Both branches end at the same check questions."
pause

# --------------------------------------------------------------------------
hdr "BEAT 3 — THE HISTORY: how release_agent worked, and why it died"
hr
say "The v1 recipe (memorize the SHAPE — it is act2's recipe with the"
say "twist that no in-cage execution was ever needed):"
cat <<'EOF'
    1. A privileged container MOUNTS ITS OWN cgroup v1 hierarchy
       (a free controller, e.g. rdma — 'mount -t cgroup -o rdma ...')
    2. Creates a child cgroup, arms it:  echo 1 > x/notify_on_release
    3. Points the parent's release_agent at a payload whose path the
       INIT mount namespace can resolve (act2/02 bridges)
    4. Joins the child:                echo $$ > x/cgroup.procs
    5. LEAVES (exits). The cgroup becomes empty.
    6. The kernel runs the payload — REAL root, init namespaces.
       The trigger was: a DIRECTORY BECAME EMPTY.
EOF
say ""
say "Why the kernel redesign killed it:"
say "  'The kernel runs a program when a cgroup empties' is a kernel-"
say "  executed callback with an attacker-writable PATH. The v2 designers"
say "  did not restrict it (perms, namespaces) — they DELETED the semantic."
say "  'Run a program on empty' moved to user-space daemons (systemd,"
say "  Kubernetes itself) where it runs as a bounded, non-kernel service."
say "  That is remediation at the deepest possible layer: not config,"
say "  not mounts, not capabilities — DESIGN."
pause

# --------------------------------------------------------------------------
hdr "BEAT 4 — THE LESSON: what survived, what did not"
hr
say "Run a final inventory on this machine:"
say "    cat /proc/sys/kernel/core_pattern     (EXISTS — still exploitable; act3/01)"
say "    cat /sys/kernel/uevent_helper        (EXISTS — still exploitable; act3/02)"
say "    ls /proc/sys/fs/binfmt_misc/         (EXISTS — still exploitable; act3/03)"
say "    find /sys/fs/cgroup -name release_agent   (ABSENT — remediated by design)"
say ""
say "Three of four usermode-helper escapes are alive on the most modern"
say "kernel you can boot today. One is not. The defense lessons stack:"
say "    release_agent      → fixed by kernel redesign (wait for the ecosystem)"
say "    core_pattern, uevent_helper, binfmt_misc → fixed by YOU, per pod:"
say "        privileged: false, capabilities.drop: [ALL], maskedPaths,"
say "        readOnlyRootFilesystem, Pod Security Standards 'restricted'"
say "The v2 migration removed exactly one technique — your cluster is only"
say "as safe as the other three's remediations. Run the act4 matrix with"
say "release_agent's row marked 'kernel-fixed', and act5 confirms the rest."
pause

# --------------------------------------------------------------------------
hdr "CHECK QUESTIONS (act3/04, v2 branch) — act 3 is complete"
cat <<'EOF'
  1. Compare the v1 recipe's step 6 trigger ('a directory became empty')
     to the other three techniques' triggers. Which needed NO in-cage
     execution at all — and why did that make it scarier, not less?
  2. The v2 fix was DELETION, not restriction. Name one trade-off the
     kernel team accepted (hint: what legitimate v1 use of release_agent
     had to move to user space, and who owns it now?)
  3. Your beat-1 predictions: were 'absent' and 'redesigned' both right?
     If so, you can now read a kernel redesign as a security finding.

  Act 4: act4-matrix.md — fill it; release_agent's remediation cell says
  'kernel redesign (v2) — technique extinct'. Then:
  Act 5: act5-cluster/01-kind.sh — the lessons become a scanner run.
EOF
