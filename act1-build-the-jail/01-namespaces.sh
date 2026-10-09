#!/usr/bin/env bash
# act1/01-namespaces.sh — shrink your view of the world, one namespace at a time.
# Terminal: lab (B). Uses sudo (02-userns.sh shows the unprivileged way).
#
# PATTERN (same in every beat, learn it here):
#   1. The script prepares something on the HOST (or just describes it)
#   2. The script DROPS YOU INTO a namespace — a live shell, prompt [INSIDE]
#   3. YOU run the observation commands inside (the script prints them first)
#   4. YOU switch to Terminal A and run the twin command on the host
#   5. YOU type 'exit' to leave the namespace; the script debriefs and moves on
#
# The [INSIDE] prompt is the lab's safety habit: from act3 on, running an
# escape in the wrong terminal is the one mistake we cannot afford, so the
# marker starts here, in the friendliest act.
#
# CLEANUP: an EXIT/INT trap removes the IPC queue if the script is Ctrl-C'd;
# everything else lives inside namespaces and dies when you 'exit'.

set -euo pipefail

hr()   { printf '\n\033[1m%s\033[0m\n' "----------------------------------------------------------------"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
say()  { printf '  %s\n' "$*"; }
pause(){ printf '\n  \033[2m[press Enter for the next beat]\033[0m'; read -r; }
INSIDE_PROMPT='\[\033[35m\][INSIDE]\[\033[0m\] \$ '

# Drop the user into a namespaced interactive shell.
# Usage: enter -i   /   enter -fp --mount-proc   (flags passed to unshare)
enter() {
    sudo env PS1="$INSIDE_PROMPT" unshare "$@" bash
}

# --- cleanup: IPC queue survives a Ctrl-C; nothing else can leak -----------
QID=""
q_exists() { [[ -n "$QID" ]] && ipcs -q 2>/dev/null | awk -v q="$QID" '$2 == q' | grep -q .; }
cleanup() {
    if q_exists; then
        sudo ipcrm -q "$QID" 2>/dev/null && say "cleanup: removed leftover ipc queue $QID" || true
    fi
}
trap cleanup EXIT INT TERM

# --------------------------------------------------------------------------
hdr "BEAT 1 — uts namespace: your hostname is a lie"
hr
say "UTS isolates the hostname. You are about to get a prompt in a new"
say "uts namespace. Run inside:"
say "    hostname jail"
say "    hostname"
say "Then in Terminal A (host) run:"
say "    hostname"
say "Compare: inside says 'jail', the host never moved."
say "Type 'exit' to come back."
hr
enter -u
say "debrief: the two hostnames were different. Same machine — different VIEW."
pause

# --------------------------------------------------------------------------
hdr "BEAT 2 — ipc namespace: shared memory you cannot see"
hr
say "First the script makes a HOST-side message queue, so there is"
say "something to hide from you:"
QID=$(sudo ipcmk -Q | sed 's/.*id //')
say "    host queue id: $QID   (visible in Terminal A with: ipcs -q)"
say ""
say "You are about to enter an ipc namespace. Run inside:"
say "    ipcs -q            (the host queue is INVISIBLE)"
say "    ipcmk -Q           (make YOUR OWN queue inside; note its id)"
say "Then in Terminal A:"
say "    ipcs -q            (host queue present, YOUR queue absent)"
say "Isolation is symmetric: out cannot see in, in cannot see out."
say "Type 'exit' to come back."
hr
enter -i
say "debrief: two queues existed at once, each visible from only one side."
pause

# --------------------------------------------------------------------------
hdr "BEAT 3 — pid namespace: /proc shrinks to a handful of processes"
hr
say "PID gives the namespace its own process ids, numbering from 1."
say "--mount-proc mounts a FRESH /proc inside (the old /proc would still"
say "show host pids — the two flags go together)."
say ""
say "Run inside:"
say "    echo \$\$                          (your shell's pid — small!)"
say "    ls /proc | grep -c '^[0-9]'      (how many processes exist here)"
say "    ps aux                           (look around: nearly empty)"
say "Then in Terminal A:"
say "    ps aux | wc -l                   (hundreds. They never went anywhere.)"
say "Type 'exit' to come back."
hr
enter -fp --mount-proc
say "debrief: same kernel, one process table per pid namespace. The view"
say "is the isolation — the processes were on the same machine all along."
pause

# --------------------------------------------------------------------------
hdr "BEAT 4 — net namespace: the network disappears"
hr
say "NET gives a private network stack: interfaces, routes, sockets."
say ""
say "Run inside:"
say "    ip a                            (only 'lo', and it is DOWN)"
say "    cat /etc/resolv.conf            (note: still the host's FILE —"
say "                                     namespaces isolate kernel objects,"
say "                                     not the filesystem)"
say "Then in Terminal A:"
say "    ip a                            (the real interfaces are all still there)"
say "Type 'exit' to come back."
hr
enter -n
say "debrief: the inside world has no route to anything. Reconnecting that"
say "world (veth pairs, CNI) is precisely what Kubernetes pod networking does."
pause

# --------------------------------------------------------------------------
hdr "BEAT 5 — mount namespace: your mounts are private"
hr
say "MNT gives a private mount table. You will mount a tmpfs INSIDE,"
say "prove it exists from one side and not the other, then kill it by"
say "simply leaving."
say ""
say "Run inside:"
say "    mount -t tmpfs tmpfs /mnt"
say "    echo hello > /mnt/proof"
say "    grep ' /mnt ' /proc/mounts       (your tmpfs: present)"
say "Then in Terminal A:"
say "    grep ' /mnt ' /proc/mounts       (NOT PRESENT on the host)"
say "    ls /mnt/proof                     (No such file)"
say "Type 'exit' — and notice the tmpfs does not survive you."
hr
enter -m
say "debrief: mounts made inside a mount namespace live and die with it."
say "This is why container filesystems can be disposable."
pause

# --------------------------------------------------------------------------
hdr "BEAT 6 — all of it at once: you are standing in a room now"
hr
say "One unshare, five walls (uts ipc pid net mnt). This shell is, kernel-"
say "feature-wise, most of a container already. Run inside:"
say "    hostname jail"
say "    hostname ; ls /proc | grep -c '^[0-9]' ; ip a ; whoami"
say "Then in Terminal A: hostname; ps aux | wc -l; ip a"
say ""
say "Watch the one thing that did NOT change inside: whoami."
say "You are still REAL root. Fake root is the next script."
say "Type 'exit' to come back."
hr
enter -fpimnu --mount-proc
say "debrief: five views flipped, identity untouched. 'Root' is next."

# --------------------------------------------------------------------------
hdr "RESIDUE CHECK (automatic) — prove the lab leaves nothing behind"
if q_exists; then
    say "this script's queue $QID still present: YES (bug — remove with: sudo ipcrm -q $QID)"
else
    say "this script's queue $QID still present: NO"
fi
# any OTHER queues are not ours — but flag ones owned by you: they usually
# mean an 'ipcmk' ran outside the namespace by mistake (wrong terminal)
orphans=$(ipcs -q | tail -n +4 | awk -v u="$USER" '$3 == u {print $2}' || true)
if [[ -n "$orphans" ]]; then
    say "queues owned by $USER (likely created outside a namespace):"
    for q in $orphans; do say "    msqid $q → remove with: ipcrm -q $q"; done
    say "→ how this happens: 'ipcmk -Q' run in the host shell instead of the"
    say "  [INSIDE] prompt. The prompt marker is there to prevent exactly this."
else
    say "no orphan queues owned by $USER"
fi
say "tmpfs on /mnt visible on the host: $(grep -c ' /mnt ' /proc/mounts || true)"
say "hostname on the host: $(hostname) (unchanged means: the jail died with you)"

hdr "CHECK QUESTIONS (act1/01) — answer before moving on"
cat <<'EOF'
  1. Which namespace(s) stop a process from seeing the host's processes?
  2. Which one hides the host's mount table?
  3. In beat 3, where were the host's hundreds of processes while you saw 3?
  4. PREDICTION for 02-userns.sh: unshare -U makes you "root" inside without
     being root outside. What do you predict 'id' shows inside vs outside?

  Next: act1-build-the-jail/02-userns.sh
EOF
