#!/usr/bin/env bash
# act2/02-path-resolution.sh — the bridge: your files, reachable from outside.
# Terminal: lab (B) + host (A) — this is a TWO-TERMINAL script, the core one.
# Uses sudo.
#
# The prediction from 02/01: a knob needs the exact string that resolves in
# the HOST's mount namespace to a file the container controls. This script
# builds and proves the three bridge mechanisms, then commits the recipe.
#
# Beats:
#   1. The container: overlay rootfs + pivot_root (act1/06 reborn, persistent)
#   2. Bridge 1: the upperdir path — the host's direct door
#   3. Bridge 2: /proc/<pid>/root — the host's universal door into ANY process
#   4. Bridge 3: hostPath volumes — Kubernetes handing you the door key
#   5. The recipe, committed (act3 follows it four times)
#
# CLEANUP: the jail lives in a private mount ns (dies on exit); trap removes
# the persistent payload directory.

set -euo pipefail

hr()   { printf '\n\033[1m%s\033[0m\n' "----------------------------------------------------------------"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
say()  { printf '  %s\n' "$*"; }
pause(){ printf '\n  \033[2m[press Enter for the next beat]\033[0m'; read -r; }
JAIL_PROMPT='\[\033[35m\][INSIDE-JAIL]\[\033[0m\] \$ '

ROOTFS=/tmp/lab-jailroot        # the container's rootfs (an overlay over this)
PAYLOAD_DIR=/tmp/lab-escape     # the payload both worlds must reach
MARKER=$PAYLOAD_DIR/marker

[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"

cleanup() {
    [[ -d "$ROOTFS" ]] && rm -rf "$ROOTFS"
    [[ -f "$PAYLOAD_DIR/payload.sh" ]] && rm -f "$PAYLOAD_DIR/payload.sh"
    say "cleanup: removed $ROOTFS and $PAYLOAD_DIR/payload.sh (marker left for your reading)"
    return 0
}
trap cleanup EXIT INT TERM

# --------------------------------------------------------------------------
hdr "BEAT 0 — the prediction from 02/01"
hr
say "Your prediction: the exact string a knob needs to run /payload.sh that"
say "a container wrote. Write it down. Beats 2-4 will grade it."
pause

# --------------------------------------------------------------------------
hdr "BEAT 1 — rebuild the jail (you know every syscall by now)"
hr
say "The script builds an overlay rootfs (act1/05) and pivots into it"
say "(act1/06) — a persistent jail with a REAL root filesystem separation."
mkdir -p "$ROOTFS"/{bin,dev,proc,sys,etc,tmp,oldroot}
cp /bin/busybox "$ROOTFS/bin/"
for app in sh ls cat ps mount echo sleep; do ln -sf busybox "$ROOTFS/bin/$app"; done
mkdir -p "$PAYLOAD_DIR"
say "Prepared. You will be dropped inside in beat 2 — leave the script"
say "running and READ the beats from Terminal A as you go."
pause

# --------------------------------------------------------------------------
hdr "BEAT 2 — bridge 1: write through the merged view, read from outside"
hr
say "YOU (Terminal B) go inside the jail. The script told you the plan: run"
say "inside:"
say "    echo 'echo \"ESCAPED via upperdir at \$$(date) as \$(id -un)\" >> /tmp/marker' > /tmp/payload.sh"
say "    cat /tmp/payload.sh         (written — but WHERE, physically?)"
say "    ls /tmp                     (your view: it lives in YOUR rootfs)"
say "Then in Terminal A (host):"
say "    ls /tmp/lab-jailroot/tmp/payload.sh      (IT IS THERE. Same file.)"
say "    cat /tmp/lab-jailroot/tmp/payload.sh"
say ""
say "The host-side path /tmp/lab-jailroot/tmp/payload.sh is bridge 1: the"
say "UPPERDIR of your container's rootfs, reached from the host's mount ns."
say "That path string — an upperdir path — is a VALID knob payload path."
say "Type 'exit' to come back."
hr
env PS1="$JAIL_PROMPT" unshare -mfp --mount-proc bash -c "
    mount --bind $ROOTFS $ROOTFS
    cd $ROOTFS
    pivot_root . oldroot
    umount -l /oldroot
    mount -t proc proc /proc
    exec /bin/sh
"
pause

# --------------------------------------------------------------------------
hdr "BEAT 3 — bridge 2: /proc/<pid>/root — the universal door"
hr
say "Re-enter the jail, but this time note your pid. Run inside:"
say "    echo \$\$                     (remember this number)"
say "    echo 'echo \"ESCAPED via /proc/<pid>/root\" >> /tmp/marker' > /tmp/payload2.sh"
say "    sleep 300                   (stay alive — the door works both ways)"
say "While it sleeps, in Terminal A (host):"
say "    sudo ls /proc/<pid>/root/tmp/          (YOUR rootfs, from outside)"
say "    sudo cat /proc/<pid>/root/tmp/payload2.sh"
say "Kill the sleep (Ctrl-C), 'exit' the jail, and check: does /proc/<pid>"
say "still exist? The door only exists while the process does."
hr
env PS1="$JAIL_PROMPT" unshare -mfp --mount-proc bash -c "
    mount --bind $ROOTFS $ROOTFS
    cd $ROOTFS
    pivot_root . oldroot
    umount -l /oldroot
    mount -t proc proc /proc
    exec /bin/sh
"
say "debrief: /proc/<pid>/root is why hostPID matters in Kubernetes: it"
say "makes the host's /proc contain YOUR pid — and hands every escape the"
say "bridge without needing the upperdir path at all."
pause

# --------------------------------------------------------------------------
hdr "BEAT 4 — bridge 3: hostPath volumes, Kubernetes' explicit door"
hr
say "The last bridge is not a kernel trick — it is a REQUEST. In Kubernetes:"
say "    volumes:"
say "    - name: escape-door"
say "      hostPath: { path: /tmp }              ← the node's /tmp, in your pod"
say "A pod with this mounts the NODE's directory into the container. Any file"
say "you write there is trivially host-path-addressable — knobs need no"
say "upperdir arithmetic, the manifest handed you the exact string."
say ""
say "This is why 'hostPath' is a prized finding in every cluster scanner —"
say "act5 will flag them automatically, and you will know exactly WHY."
pause

# --------------------------------------------------------------------------
hdr "BEAT 5 — the recipe, committed"
hr
say "Every act3 escape is this recipe, four times over:"
cat <<'EOF'
     (1) PAYLOAD    write a script somewhere your container controls
                    (merged view, hostPath, or any bridge dir)
     (2) BRIDGE     find the init-mount-ns string that reaches it:
                    upperdir path  |  /proc/<pid>/root/...  |  hostPath mount
     (3) KNOB       write a usermode-helper knob (needs the act1/04 caps)
     (4) TRIGGER    cause the kernel event; the helper runs as REAL root,
                    in the HOST's mount namespace — with YOUR payload
EOF
say ""
say "Grade your beat 0 prediction now. In this lab the bridges were easy"
say "(/tmp shared, jail rooted in a visible directory). In act3 the jail is"
say "privileged and the bridges stay the same — the knobs just get easier."
pause

# --------------------------------------------------------------------------
hdr "RESIDUE CHECK (automatic)"
[[ -f "$MARKER" ]] && say "marker file: present (your escape evidence — read: cat $MARKER)" || say "marker: none"
[[ -d "$ROOTFS" ]] && say "$ROOTFS: present (bug — trap should have removed it)" || say "$ROOTFS: removed"

hdr "CHECK QUESTIONS (act2/02) — the intellectual core is done"
cat <<'EOF'
  1. Name the three bridges and who creates each: the kernel runtime
     (upperdir), the process table (/proc/<pid>/root), or the operator
     (hostPath). Which one is a REQUEST, not a mechanism?
  2. Why does hostPID make /proc/<pid>/root MORE dangerous?
  3. The recipe's step 2 exists because of ONE kernel design decision.
     Name it. (Where do usermode helpers resolve paths?)

  Act 3 begins: act3-escapes/01-core_pattern.sh
  Bring the recipe. It runs four times.
EOF
