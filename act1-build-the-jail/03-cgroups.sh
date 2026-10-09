#!/usr/bin/env bash
# act1/03-cgroups.sh — build a cgroup by hand and feel it squeeze.
# Terminal: lab (B). Uses sudo. This is the CGROUP V2 branch.
#
# The prediction planted by 02-userns.sh: cgroups change what you can USE,
# not what you can SEE. Watch for the confirmation.
#
# Beats:
#   1. Confirm the world (v2) and how its files differ from v1
#   2. Create a cgroup by hand and DROP YOU INTO it (persistent shell)
#   3. Set your own memory limit, then watch your own process get
#      OOM-killed from inside the cage
#   4. FORESHADOW: hunt for a file that does NOT exist. This absence is
#      act3/04's entire lesson.
#
# CLEANUP: trap removes the lab cgroup and the OOM demo file.

set -euo pipefail

hr()   { printf '\n\033[1m%s\033[0m\n' "----------------------------------------------------------------"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
say()  { printf '  %s\n' "$*"; }
pause(){ printf '\n  \033[2m[press Enter for the next beat]\033[0m'; read -r; }
INSIDE_PROMPT='\[\033[35m\][INSIDE]\[\033[0m\] \$ '

CG_ROOT=/sys/fs/cgroup
CG_LAB=$CG_ROOT/lab
OOM_FILE=/dev/shm/lab-oom

[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"

# --- cleanup ---------------------------------------------------------------
cg_hascg()   { [[ -d "$CG_LAB" ]]; }
cleanup() {
    if cg_hascg; then
        # processes must be gone and controllers disabled before rmdir
        rmdir "$CG_LAB" 2>/dev/null || say "cleanup: cgroup $CG_LAB not empty — check cgroup.procs"
    fi
    [[ -e "$OOM_FILE" ]] && rm -f "$OOM_FILE" && say "cleanup: removed $OOM_FILE"
    return 0
}
trap cleanup EXIT INT TERM

# Drop the user into a shell INSIDE the lab cgroup (persistent pattern).
enter_cg() {
    bash -c "echo \$\$ > $CG_LAB/cgroup.procs; exec env PS1='$INSIDE_PROMPT' bash"
}

# --------------------------------------------------------------------------
hdr "BEAT 0 — your prediction from 02-userns.sh"
hr
say "Cgroups limit resources, not views. Did you predict:"
say "changes what you can SEE, or changes what you can USE?"
pause

# --------------------------------------------------------------------------
hdr "BEAT 1 — the v2 world: one hierarchy, controller files everywhere"
hr
CG_TYPE=$(stat -fc %T "$CG_ROOT")
if [[ "$CG_TYPE" == "cgroup2fs" ]]; then
    say "v2 confirmed (cgroup2fs). The v1 world had one DIRECTORY per"
    say "controller (/sys/fs/cgroup/memory, /sys/fs/cgroup/cpu...). v2 has"
    say "ONE hierarchy and per-cgroup FILES named by controller:"
else
    say "WARNING: this machine is NOT on v2 ($CG_TYPE) — use the cgroup-v1"
    say "branch of this repository. The beats below will not work here."
    exit 1
fi
say "Run in Terminal A:"
say "    ls $CG_ROOT | head -20           (flat: cgroup.procs, memory.max, ...)"
say "    cat $CG_ROOT/cgroup.controllers  (what CAN be enabled here)"
say "    cat $CG_ROOT/cgroup.subtree_control   (what IS enabled for children)"
say ""
say "The v2 trick to know: a cgroup can only USE a controller if its PARENT"
say "enabled it via subtree_control. Enabling is a WRITE to the parent:"
say "    echo +memory > $CG_ROOT/cgroup.subtree_control"
pause

# --------------------------------------------------------------------------
hdr "BEAT 2 — create a cgroup by hand, then step inside it"
hr
say "On the host (or here — preparation either way):"
say "    echo +memory > $CG_ROOT/cgroup.subtree_control    (arm memory for children)"
if ! grep -q memory "$CG_ROOT/cgroup.subtree_control"; then
    echo +memory > "$CG_ROOT/cgroup.subtree_control"
fi
say "    mkdir $CG_LAB"
[[ -d "$CG_LAB" ]] || mkdir "$CG_LAB"
say "done: a directory IS a cgroup, same as v1 — that part did not change."
say ""
say "You are about to be dropped into a shell INSIDE \$CG_LAB:"
say "    (the script writes the shell's pid into the cgroup's 'cgroup.procs')"
say "Run inside:"
say "    cat $CG_LAB/cgroup.procs         (your shell's pid)"
say "    cat /proc/self/cgroup            (kernel's answer: 0::/lab)"
say "    cat $CG_LAB/memory.max           (v2's limit file — currently 'max')"
say "Then in Terminal A:"
say "    cat $CG_LAB/cgroup.procs         (same pid — you are IN the cage)"
say "Type 'exit' to come back."
hr
enter_cg
say "debrief: membership is still just a pid in a file. Kubernetes writes"
say "these same files for every container you have ever scheduled — v2 just"
say "renamed 'tasks' to 'cgroup.procs' and flattened the hierarchy."
pause

# --------------------------------------------------------------------------
hdr "BEAT 3 — set your own limit, then die from it"
hr
say "You are inside the cage; now you build the wall. Re-enter the cgroup:"
say "Run inside:"
say "    echo 64M > $CG_LAB/memory.max"
say "    cat $CG_LAB/memory.max                 (confirm: 67108864)"
say "    cat $CG_LAB/memory.current              (v2's usage file — tiny now)"
say "Then feed it past the wall (writes 512M of RAM via /dev/shm):"
say "    dd if=/dev/zero of=$OOM_FILE bs=1M count=512"
say "Read what happened: the kernel KILLED your dd (OOM). You set the limit;"
say "the same kernel you share with the host enforced it — against you."
say "    dmesg | tail -5                        (the kill, on the record)"
say "    cat $CG_LAB/memory.current             (right at the wall: ~64M)"
say "    rm -f $OOM_FILE                       (cleanup your own wreckage)"
say "Then in Terminal A:"
say "    free -m                               (the HOST lost nothing)"
say "Type 'exit' to come back."
hr
enter_cg
say "debrief: no view changed — identical to the v1 experience. The OOM"
say "semantics are the same; only the file names moved. Cgroups remain what"
say "they always were: resource isolation, not view isolation."
pause

# --------------------------------------------------------------------------
hdr "BEAT 4 — FORESHADOW: hunt the file that does not exist"
hr
say "In the v1 world, the root of each hierarchy carried a file called"
say "release_agent: 'a program the kernel runs when the LAST process"
say "leaves a cgroup'. The v1 lab branch watches it, then fires it in act3."
say "Go look for it. Run (inside or Terminal A — a read-only hunt):"
say "    ls $CG_ROOT | grep -E 'release_agent|notify_on_release'"
say "    ls $CG_LAB | grep -E 'release_agent|notify_on_release'"
say "    find /sys/fs/cgroup -name 'release_agent' 2>/dev/null"
say ""
say "Nothing. Not empty-with-defaults like core_pattern — ABSENT BY DESIGN."
say "The v2 redesign deleted the kernel-run-program callback entirely, and"
say "act3/04 is the story of WHY. On this branch the other three escapes"
say "(core_pattern, uevent_helper, binfmt_misc) still work — only this one"
say "was eliminated at the kernel-design level."
pause

# --------------------------------------------------------------------------
hdr "RESIDUE CHECK (automatic) — prove the lab leaves nothing behind"
if cg_hascg; then
    say "cgroup $CG_LAB still present: YES — remove: rmdir $CG_LAB (after emptying cgroup.procs)"
else
    say "cgroup $CG_LAB still present: NO (cleanup trap removed it)"
fi
[[ -e "$OOM_FILE" ]] && say "$OOM_FILE still present: YES — remove: rm -f $OOM_FILE" || say "oom demo file: NO"

hdr "CHECK QUESTIONS (act1/03, v2 branch) — answer before moving on"
cat <<'EOF'
  1. In v2, why did beat 2 need a write to the PARENT's subtree_control
     before the lab cgroup could do anything? What v1 concept did this
     replace (hint: one-directory-per-controller)?
  2. v1's 'tasks' is v2's 'cgroup.procs'; v1's 'memory.limit_in_bytes' is
     v2's 'memory.max'. Which v1 file has NO v2 counterpart, and what did
     the designers remove along with it?
  3. In beat 3 the view never changed but a process died. Which half of
     "container isolation" is cgroups responsible for — on BOTH versions?

  PREDICTION for 04-capabilities.sh: writing cgroup files needed root.
  In 04 we drop capabilities ONE AT A TIME and watch things break.
  Predict: which capability, if dropped, would make beat 2's
  'echo $$ > cgroup.procs' fail?

  Next: act1-build-the-jail/04-capabilities.sh
EOF
