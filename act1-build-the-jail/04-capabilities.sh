#!/usr/bin/env bash
# act1/04-capabilities.sh — drop capabilities and watch things break.
# Terminal: lab (B). Uses sudo.
#
# The prediction from 03-cgroups.sh: writing cgroup files needed root.
# Here we find out WHICH PART of root: capabilities. We drop them ONE AT A
# TIME and watch specific operations die — the vocabulary for act3's matrix.
#
# Beats:
#   1. Read your capability set (it is just bits in /proc/self/status)
#   2. Drop CAP_SYS_TIME  → set the clock: dies
#   3. Drop CAP_SYS_ADMIN → mount: dies
#   4. Drop CAP_NET_RAW   → ping: maybe still works! (file capabilities)
#   5. Compare: full root set vs container default vs privileged container
#
# CLEANUP: nothing to clean — capabilities are per-process and die with the
# shells we spawn. No residue check needed beyond the debriefs.

set -euo pipefail

hr()   { printf '\n\033[1m%s\033[0m\n' "----------------------------------------------------------------"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
say()  { printf '  %s\n' "$*"; }
pause(){ printf '\n  \033[2m[press Enter for the next beat]\033[0m'; read -r; }
INSIDE_PROMPT='\[\033[35m\][INSIDE]\[\033[0m\] \$ '

[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"

# Drop capabilities in a PERSISTENT shell (capsh removes them from the
# bounding set too, so not even file-capable binaries can regain them).
enter_drop() {
    env PS1="$INSIDE_PROMPT" capsh --drop="$1" -- -i
}

# --------------------------------------------------------------------------
hdr "BEAT 0 — your prediction from 03-cgroups.sh"
hr
say "Which capability, if dropped, would make 'echo \$\$ > tasks' fail?"
say "Hold your answer; beat 5 tells you if you were right."
pause

# --------------------------------------------------------------------------
hdr "BEAT 1 — your capability set is four numbers in /proc"
hr
say "Capabilities are not mystical: they are bit sets, readable here."
say "Run (host or inside — same for root):"
say "    grep ^Cap /proc/self/status"
say "    capsh --print | head -8                (decoded for humans)"
say "    capsh --decode=\$(grep ^CapEff /proc/self/status | awk '{print \$2}')"
say ""
say "Four sets: Inheritable, Permitted, Effective, Bounding (plus Ambient)."
say "The EFFECTIVE set is what the kernel consults on every privileged syscall."
pause

# --------------------------------------------------------------------------
hdr "BEAT 2 — drop CAP_SYS_TIME: the clock becomes untouchable"
hr
say "You get a root shell with ONE capability removed. Run inside:"
say "    capsh --print | grep -i current         (see it gone)"
say "    date -s '2030-01-01 00:00:00'           (dies: Operation not permitted)"
say "Then in Terminal A:"
say "    date                                     (the host clock never moved)"
say "Type 'exit' to come back."
hr
enter_drop cap_sys_time
say "debrief: EPERM. The syscall happened; the kernel checked your effective"
say "set first and refused. One bit in CapEff = one class of power."
pause

# --------------------------------------------------------------------------
hdr "BEAT 3 — drop CAP_SYS_ADMIN: the master key of act3"
hr
say "Same drill, the big one. Run inside:"
say "    mount -t tmpfs tmpfs /mnt               (dies: Operation not permitted)"
say "    strace -e trace=mount mount -t tmpfs tmpfs /mnt   (EPERM, on the record)"
say "Then in Terminal A: mounts unchanged."
say "Type 'exit' to come back."
hr
enter_drop cap_sys_admin
say "debrief: CAP_SYS_ADMIN is the capability behind: mounting, cgroup file"
say "writes (your prediction in beat 0 — right answer), pivot_root config,"
say "and MOST of the knobs in act3. This is why 'privileged: true' is really"
say "'CAP_SYS_ADMIN plus everything else', and why dropping ONE bit kills"
say "entire attack classes."
pause

# --------------------------------------------------------------------------
hdr "BEAT 4 — drop CAP_NET_RAW: ping... survives?! (file capabilities)"
hr
say "The twist beat. Run inside:"
say "    ping -c1 127.0.0.1"
say "If it STILL WORKS — the binary rescued itself:"
say "    getcap \$(command -v ping)                (cap_net_raw=ep ON THE FILE)"
say "If it DIES — the capsh drop removed the capability from the BOUNDING"
say "set too, so the file's request to raise it was denied."
say "Type 'exit' to come back."
hr
enter_drop cap_net_raw
say "debrief: capabilities attach to FILES as well as processes. Containers"
say "rely on this: a dropped bounding set is the wall between file asks and"
say "process power. Either outcome teaches the same mechanism."
pause

# --------------------------------------------------------------------------
hdr "BEAT 5 — root vs container vs privileged, side by side"
hr
say "Three capability sets you now know how to read. Run:"
say "    capsh --decode=000001ffffffffff         (a privileged container: ~everything)"
say "    capsh --decode=00000000a80425fb         (a NORMAL container's default)"
say "    capsh --decode=00000000a80425fb | tr ',' '\n' | grep -c cap_   (count them)"
say ""
say "The normal container set excludes: SYS_ADMIN, SYS_TIME, SYS_MODULE,"
say "SYS_RAWIO... the exact caps whose drops you just FELT in beats 2-4."
say "A privileged container re-adds them — which is act3's entire setup."
pause

# --------------------------------------------------------------------------
hdr "CHECK QUESTIONS (act1/04) — answer before moving on"
cat <<'EOF'
  1. CAP_SYS_ADMIN dropped: name three operations that die (one is act3's
     core requirement — cgroup file writes).
  2. Ping survived a CAP_NET_RAW drop in the bounding-set shell (maybe).
     What mechanism could grant a capability to a process that does not
     hold it in its bounding set... and what stops it?
  3. If you could add ONLY ONE line to a pod's securityContext, which
     capability removal would kill the most act3 techniques?

  PREDICTION for 05-overlayfs.sh: mounting the overlay in the next script
  needs a capability. Which one — and is it the same one pivot_root needs?

  Next: act1-build-the-jail/05-overlayfs.sh
EOF
