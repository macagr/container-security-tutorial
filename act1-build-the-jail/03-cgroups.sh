#!/usr/bin/env bash
# act1/03-cgroups.sh — build a cgroup by hand and feel it squeeze.
# Terminal: lab (B). Uses sudo. Machine is expected to be on cgroup v1
# (setup/02-cgroup-mode.sh --set-v1); a v2 sidebar is mounted in beat 5.
#
# The prediction planted by 02-userns.sh: cgroups change what you can USE,
# not what you can SEE. Watch for the confirmation.
#
# Beats:
#   1. Detect the cgroup world (v1 here)
#   2. Create a memory cgroup by hand and DROP YOU INTO it (persistent shell)
#   3. Set your own memory limit, then watch your own process get
#      OOM-killed from inside the cage
#   4. FORESHADOW: look at release_agent in the hierarchy root. Do not touch.
#   5. V2 PREVIEW: mount a cgroup2 hierarchy side by side; see what v1
#      has that v2 does not. (Act 3 beat 4 pays this off.)
#
# CLEANUP: trap removes the lab cgroup, unmounts the v2 preview, deletes
# the OOM demo file in /dev/shm.

set -euo pipefail

hr()   { printf '\n\033[1m%s\033[0m\n' "----------------------------------------------------------------"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
say()  { printf '  %s\n' "$*"; }
pause(){ printf '\n  \033[2m[press Enter for the next beat]\033[0m'; read -r; }
INSIDE_PROMPT='\[\033[35m\][INSIDE]\[\033[0m\] \$ '

CG_ROOT=/sys/fs/cgroup/memory
CG_LAB=$CG_ROOT/lab
V2_MNT=/mnt/cgroup2-preview
OOM_FILE=/dev/shm/lab-oom

[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"

# --- cleanup ---------------------------------------------------------------
cg_hascg()   { [[ -d "$CG_LAB" ]]; }
v2_mounted() { grep -qs " $V2_MNT " /proc/mounts; }
cleanup() {
    # empty the cgroup first (tasks must be gone before rmdir)
    if cg_hascg; then
        rmdir "$CG_LAB" 2>/dev/null || say "cleanup: cgroup $CG_LAB not empty — check tasks file"
    fi
    v2_mounted && { umount "$V2_MNT" && rmdir "$V2_MNT" && say "cleanup: unmounted v2 preview"; } || true
    [[ -e "$OOM_FILE" ]] && rm -f "$OOM_FILE" && say "cleanup: removed $OOM_FILE"
    return 0
}
trap cleanup EXIT INT TERM

# Drop the user into a shell INSIDE the lab cgroup (persistent pattern).
# The inner bash writes its own pid into tasks, then execs the prompt shell.
enter_cg() {
    bash -c "echo \$\$ > $CG_LAB/tasks; exec env PS1='$INSIDE_PROMPT' bash"
}

# --------------------------------------------------------------------------
hdr "BEAT 0 — your prediction from 02-userns.sh"
hr
say "Cgroups limit resources, not views. Did you predict:"
say "changes what you can SEE, or changes what you can USE?"
pause

# --------------------------------------------------------------------------
hdr "BEAT 1 — which cgroup world are we in?"
hr
CG_TYPE=$(stat -fc %T /sys/fs/cgroup)
case "$CG_TYPE" in
    tmpfs)     say "v1 (hierarchies under $CG_ROOT) — release_agent EXISTS (act3 payoff enabled)" ;;
    cgroup2fs) say "v2 (unified) — release_agent does NOT exist; see beat 5 for the comparison" ;;
    *)         say "unknown mount type: $CG_TYPE — stop and check" ; exit 1 ;;
esac
say "the canonical check, same one from setup/00:"
say "    stat -fc %T /sys/fs/cgroup"
say ""
say "A cgroup is not a namespace trick: it is just a DIRECTORY in a"
say "pseudo-filesystem, and you configure it by writing FILES."
say "Run in Terminal A:"
say "    ls /sys/fs/cgroup/          (one directory per controller)"
say "    ls /sys/fs/cgroup/memory/   (the memory hierarchy — your cage parts)"
pause

# --------------------------------------------------------------------------
hdr "BEAT 2 — create a cgroup by hand, then step inside it"
hr
say "On the host (Terminal A) or here — this beat is preparation either way:"
say "    mkdir $CG_LAB"
[[ -d "$CG_LAB" ]] || mkdir "$CG_LAB"
say "done: a directory IS a cgroup. You now have one. Watch it register you."
say ""
say "You are about to be dropped into a shell that is INSIDE \$CG_LAB:"
say "    (the script writes the shell's pid into the cgroup's 'tasks' file)"
say "Run inside:"
say "    cat $CG_LAB/tasks          (your shell's pid, and nothing else)"
say "    cat /proc/self/cgroup      (the kernel's own answer: you are in 'lab')"
say "Then in Terminal A:"
say "    cat $CG_LAB/tasks          (same pid — you are IN the cage now)"
say "Type 'exit' to come back."
hr
enter_cg
say "debrief: membership is just a pid in a file. Kubernetes writes these"
say "same files for every container you have ever scheduled."
pause

# --------------------------------------------------------------------------
hdr "BEAT 3 — set your own limit, then die from it"
hr
say "You are inside the cage; now you build the wall. Re-enter the cgroup:"
say "Run inside:"
say "    echo 64M > $CG_LAB/memory.limit_in_bytes"
say "    cat $CG_LAB/memory.limit_in_bytes    (confirm: 67108864)"
say "    cat $CG_LAB/memory.usage_in_bytes    (your current usage: tiny)"
say "Then feed it past the wall (this writes 512M of RAM via /dev/shm):"
say "    dd if=/dev/zero of=$OOM_FILE bs=1M count=512"
say "Read what happened: the kernel KILLED your dd (OOM). You set the limit;"
say "the same kernel you share with the host enforced it — against you."
say "    dmesg | tail -5                        (the kill, on the record)"
say "    cat $CG_LAB/memory.usage_in_bytes     (right at the wall: ~64M)"
say "    rm -f $OOM_FILE                       (cleanup your own wreckage)"
say "Then in Terminal A:"
say "    free -m                               (the HOST lost nothing)"
say "Type 'exit' to come back."
hr
enter_cg
say "debrief: no view changed — /proc, mounts, network all looked the same."
say "The prediction is answered: cgroups change what you can USE."
say "Isolation of RESOURCES, not of VIEWS. Both halves of a container now."
pause

# --------------------------------------------------------------------------
hdr "BEAT 4 — FORESHADOW: a file you should not touch (yet)"
hr
say "In the ROOT of the memory hierarchy lives a file you may have never"
say "read about. Look at it, read its default value, and DO NOT write it."
say "Run (inside or Terminal A — it is read-only curiosity):"
say "    ls $CG_ROOT | grep -E 'release_agent|notify_on_release'"
say "    cat $CG_ROOT/release_agent           (default: empty)"
say "    cat $CG_ROOT/notify_on_release       (default: 0)"
say ""
say "release_agent: 'a program the kernel runs when the LAST process leaves"
say "a cgroup'. notify_on_release: per-cgroup arming switch."
say "Empty + 0 = harmless. Remember beat 2 of 02-userns.sh: the kernel"
say "running a program for you, as REAL root, outside your namespace."
say "This file is act3's fourth escape. All we add there is a path."
pause

# --------------------------------------------------------------------------
hdr "BEAT 5 — v2 PREVIEW: the same cage, rebuilt, minus one file"
hr
say "Modern kernels replaced this design with 'unified hierarchy' (v2)."
say "We mount one side by side — no reboot, no flags:"
say "    mkdir $V2_MNT && mount -t cgroup2 none $V2_MNT"
mkdir -p "$V2_MNT"; mount -t cgroup2 none "$V2_MNT" 2>/dev/null || say "(already mounted)"
say "Now compare the two worlds. Run:"
say "    ls $V2_MNT | head -20                (one hierarchy, all controllers)"
say "    ls $V2_MNT | grep -c release_agent   (ZERO — the file does not exist)"
say "    ls $V2_MNT | grep -E 'memory.max|memory.high'   (v2's limit files)"
say ""
say "v2 has memory.max (the limit you set in beat 3) — but no release_agent,"
say "and no notify_on_release. The kernel REDESIGNED the trigger away."
say "Act 3 beat 4 will return to this directory: the escape works on v1"
say "and CANNOT work here. On your laptop right now (Terminal A):"
say "    stat -fc %T /sys/fs/cgroup           (tmpfs — you are on v1 today)"
pause

# --------------------------------------------------------------------------
hdr "RESIDUE CHECK (automatic) — prove the lab leaves nothing behind"
if cg_hascg; then
    say "cgroup $CG_LAB still present: YES — remove with: rmdir $CG_LAB (after checking tasks is empty)"
else
    say "cgroup $CG_LAB still present: NO (cleanup trap removed it)"
fi
if v2_mounted; then
    say "v2 preview still mounted at $V2_MNT: YES — remove with: umount $V2_MNT && rmdir $V2_MNT"
else
    say "v2 preview still mounted: NO"
fi
[[ -e "$OOM_FILE" ]] && say "$OOM_FILE still present: YES — remove with: rm -f $OOM_FILE" || say "oom demo file: NO"

hdr "CHECK QUESTIONS (act1/03) — answer before moving on"
cat <<'EOF'
  1. A cgroup directory appeared the moment you ran mkdir. What kernel
     object did that directory create?
  2. In beat 3 the view never changed but a process died. Which half of
     "container isolation" is cgroups responsible for?
  3. release_agent + notify_on_release: default values, and why is the
     combination harmless by default? What two things would make it
     dangerous? (You will do both in act3.)
  4. v2 removed release_agent entirely. What does that tell you about how
     the kernel team classified it?

  PREDICTION for 04-capabilities.sh: writing cgroup files needed root. In
  04 we drop capabilities ONE AT A TIME and watch things break. Predict:
  which capability, if dropped, would make beat 2's 'echo $$ > tasks' fail?

  Next: act1-build-the-jail/04-capabilities.sh
EOF
