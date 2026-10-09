#!/usr/bin/env bash
# act1/06-pivot_root.sh — the moment you built a container.
# Terminal: lab (B). Uses sudo. busybox-static required (setup/01-packages.sh).
#
# Beats:
#   1. Build a minimal rootfs by hand (busybox + mountpoints)
#   2. pivot_root into it — a persistent [INSIDE-JAIL] shell
#   3. Look around: you are in the container you built with syscalls
#   4. Debrief: what Docker/Kubernetes add (nothing kernel-level)
#
# CLEANUP: the pivot happens inside a private mount namespace; exiting the
# jail removes everything. Rootfs dir removed by trap.

set -euo pipefail

hr()   { printf '\n\033[1m%s\033[0m\n' "----------------------------------------------------------------"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
say()  { printf '  %s\n' "$*"; }
pause(){ printf '\n  \033[2m[press Enter for the next beat]\033[0m'; read -r; }
JAIL_PROMPT='\[\033[35m\][INSIDE-JAIL]\[\033[0m\] \$ '

ROOTFS=/tmp/lab-rootfs

[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"

[[ -x /bin/busybox ]] || { say "busybox not found at /bin/busybox — run setup/01-packages.sh first"; exit 1; }

cleanup() { [[ -d "$ROOTFS" ]] && rm -rf "$ROOTFS" && say "cleanup: removed $ROOTFS"; return 0; }
trap cleanup EXIT INT TERM

# --------------------------------------------------------------------------
hdr "BEAT 1 — build a rootfs with your hands"
hr
say "A rootfs is just a directory tree with the right shape. The script builds:"
mkdir -p "$ROOTFS"/{bin,dev,proc,sys,etc,tmp,oldroot}
cp /bin/busybox "$ROOTFS/bin/"
chroot "$ROOTFS" /bin/busybox --install -s /bin 2>/dev/null || \
    for app in sh ls cat ps mount echo; do ln -sf busybox "$ROOTFS/bin/$app"; done
echo "nameserver 10.0.0.1" > "$ROOTFS/etc/resolv.conf"
say "    $ROOTFS : busybox + /bin /dev /proc /sys /etc /tmp /oldroot"
say ""
say "Look at it from Terminal A:"
say "    ls $ROOTFS/bin          (a working userland, 1 static binary)"
say "That is a container image. A directory. Nothing more."
pause

# --------------------------------------------------------------------------
hdr "BEAT 2 — pivot_root: swap the floor of the world"
hr
say "chroot HIDES the old root (recoverable). pivot_root SWAPS it (the old"
say "root becomes a mount you can drop). Both need CAP_SYS_CHROOT/SYS_ADMIN."
say ""
say "You are about to be dropped inside a mount namespace, pivoted into the"
say "rootfs, with the old root unmounted and a fresh /proc mounted — a"
say "persistent [INSIDE-JAIL] shell. Every step the script performs is one"
say "syscall you now recognize."
say ""
say "Run inside (look around, break nothing):"
say "    ls /                        (busybox world: 7 dirs)"
say "    echo \$\$                     (a pid that did not exist on the host table)"
say "    ps                          (your private process view)"
say "    mount | head -5             (fresh /proc, no host mounts)"
say "Then in Terminal A:"
say "    ps aux | grep \$\$(nope — your jail pid is NOT in the host table"
say "    sudo ls /proc/\$\$/root  ...works from the host side — remember this for act2/02!)"
say "Type 'exit' to come back."
hr
env PS1="$JAIL_PROMPT" unshare -mfp --mount-proc bash -c "
    mount --bind $ROOTFS $ROOTFS
    cd $ROOTFS
    pivot_root . oldroot
    umount -l /oldroot
    exec /bin/sh
"
say "debrief: pivot_root does not change WHICH KERNEL you are talking to."
say "Same kernel, same syscalls — a different VIEW. Hold that thought for"
say "act2: the kernel's callbacks never moved either."

# --------------------------------------------------------------------------
hdr "CHECK QUESTIONS (act1/06) — answer before moving on"
cat <<'EOF'
  1. chroot vs pivot_root: why does chroot alone have a known escape
     (cd back via a saved fd) that pivot_root does not?
  2. List the kernel features that composed this jail: namespaces (which?),
     the rootfs mechanism, the /proc trick, and what capability gated it.
  3. What did Docker/Kubernetes actually ADD to what you just did by hand?
     (distribution, orchestration, defaults — zero kernel magic.)

  PREDICTION for 07-seccomp.sh: we add the last wall — a syscall filter.
     Will it inspect FILE PATHS (like /proc/sys/kernel/core_pattern) or
     only SYSCALL NAMES? What does your gut say?

  Next: act1-build-the-jail/07-seccomp.sh
EOF
