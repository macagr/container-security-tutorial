#!/usr/bin/env bash
# act1/05-overlayfs.sh — the root filesystem, and the bridge every escape crosses.
# Terminal: lab (B) + Terminal A for the host-side observation. Uses sudo.
#
# Persistent directories (both terminals can see these — that is the point):
#   /tmp/lab-overlay/{lower,upper,work,merged}
#
# Beats:
#   1. Build an overlay mount by hand (the prediction from 04: needs CAP_SYS_ADMIN)
#   2. The merged view: lowerdir files appear; writes copy-up into upperdir
#   3. THE BRIDGE: same file, two paths — inside the overlay AND on the host
#   4. Reality check: this IS what the container runtime does (/proc/mounts)
#
# CLEANUP: trap unmounts the overlay and removes /tmp/lab-overlay.

set -euo pipefail

hr()   { printf '\n\033[1m%s\033[0m\n' "----------------------------------------------------------------"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
say()  { printf '  %s\n' "$*"; }
pause(){ printf '\n  \033[2m[press Enter for the next beat]\033[0m'; read -r; }
INSIDE_PROMPT='\[\033[35m\][INSIDE]\[\033[0m\] \$ '

LAB=/tmp/lab-overlay

[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"

ov_mounted() { grep -qs " $LAB/merged " /proc/mounts; }
cleanup() {
    ov_mounted && { umount "$LAB/merged" && say "cleanup: unmounted $LAB/merged"; } || true
    [[ -d "$LAB" ]] && { rm -rf "$LAB" && say "cleanup: removed $LAB"; } || true
    return 0
}
trap cleanup EXIT INT TERM

# --------------------------------------------------------------------------
hdr "BEAT 0 — your prediction from 04-capabilities.sh"
hr
say "Mounting an overlay needs which capability? (Say it; beat 1 confirms.)"
pause

# --------------------------------------------------------------------------
hdr "BEAT 1 — build the overlay by hand"
hr
say "An overlay filesystem is THREE real directories plus one MOUNT:"
say "    lower : the image layers, read-only, stackable (lowerdir=A:B:C)"
say "    upper : where YOUR changes land               (the container's writes)"
say "    work  : overlayfs bookkeeping, never look inside"
say "    merged: the view the container actually sees"
say "Prepare the pieces (script does it, watch in Terminal A if curious):"
mkdir -p "$LAB"/{lower,upper,work,merged}
echo "i am the image layer, immutable" > "$LAB/lower/image-file.txt"
say "    $LAB created"
say ""
say "Now the mount — you type it (this is the CAP_SYS_ADMIN beat from 04):"
say "    mount -t overlay overlay \\"
say "        -o lowerdir=$LAB/lower,upperdir=$LAB/upper,workdir=$LAB/work \\"
say "        $LAB/merged"
say "You are about to be dropped into a mount namespace to do it. Run inside:"
say "    (the two mount lines above)"
say "    grep merged /proc/mounts                 (your overlay, on the record)"
say "Then in Terminal A:"
say "    grep merged /proc/mounts                 (NOT there — private mount ns)"
say "Type 'exit' to come back."
hr
env PS1="$INSIDE_PROMPT" unshare -m bash
# ensure the overlay exists for the following beats even if attendee typed it in their own ns:
if ! ov_mounted; then
    say "(script's safety net: performing the mount on the lab side for the next beats)"
    mount -t overlay overlay -o lowerdir="$LAB/lower",upperdir="$LAB/upper",workdir="$LAB/work" "$LAB/merged"
fi
say "debrief: one mount syscall turned 3 directories into one tree. That is"
say "the entire magic of 'container images' — layers are just lowerdir colon-"
say "lists. And it needed CAP_SYS_ADMIN, exactly as you predicted in beat 0."
pause

# --------------------------------------------------------------------------
hdr "BEAT 2 — the merged view and copy-up"
hr
say "You are in a fresh mount ns again. Run inside:"
say "    cat $LAB/merged/image-file.txt    (the 'image' — but which copy?)"
say "    echo \"i changed it from inside\" > $LAB/merged/image-file.txt"
say "    cat $LAB/upper/image-file.txt      (your edit, COPIED UP to upper)"
say "    cat $LAB/lower/image-file.txt      (untouched — immutable below)"
say "    echo brand-new > $LAB/merged/new-file.txt"
say "    ls $LAB/upper                       (new-file.txt materialized there)"
say "Type 'exit' to come back."
hr
env PS1="$INSIDE_PROMPT" unshare -m bash
say "debrief: writes never touch the image. They stack. 'docker commit' is"
say "'zip up upperdir'. Deletion is a whiteout. You now know what a container"
say "filesystem IS under every layer of tooling."
pause

# --------------------------------------------------------------------------
hdr "BEAT 3 — THE BRIDGE: one file, reachable from outside"
hr
say "This is the most important observation in act 1. Run here (host side):"
say "    echo \"i was written through the merged view\" >> $LAB/merged/new-file.txt"
say "Now look at the SAME bytes through the REAL path:"
say "    cat $LAB/upper/new-file.txt          (same file, host-side path)"
say ""
say "There was never a 'container filesystem'. There is ONE file on the"
say "host's disk, visible through two paths:"
say "    the merged view    (what the container calls /new-file.txt)"
say "    the upperdir path   (what the HOST calls $LAB/upper/new-file.txt)"
say ""
say "act2/02 turns this into the attack recipe: a payload written through"
say "the merged view is EXECUTABLE through the upperdir path — by a kernel"
say "callback that resolves paths in the HOST's mount namespace."
pause

# --------------------------------------------------------------------------
hdr "BEAT 4 — reality check: runtimes do exactly this"
hr
say "If docker is installed, run (host):"
say "    docker run --rm -d --name labcheck alpine sleep 300"
say "    grep -E 'overlay' /proc/\$(docker inspect -f '{{.State.Pid}}' labcheck)/mounts"
say "    docker rm -f labcheck"
say "You will see lowerdir=...upperdir=...workdir=... — beat 1's mount line,"
say "written by the runtime, with upperdir somewhere under /var/lib/docker."
say "If docker is absent: your kernel did the same thing in beat 1. Skip on."
pause

# --------------------------------------------------------------------------
hdr "RESIDUE CHECK (automatic)"
ov_mounted && say "overlay still mounted: YES (bug — remove: umount $LAB/merged)" || say "overlay still mounted: NO"
[[ -d "$LAB" ]] && say "$LAB present: YES (bug)" || say "$LAB present: NO (trap cleaned it)"

hdr "CHECK QUESTIONS (act1/05) — answer before moving on"
cat <<'EOF'
  1. You write /escape.sh inside a container whose rootfs is an overlay.
     Give two host-side paths from which that file could be opened.
  2. The merged view shows image-file.txt once. Where does it REALLY live,
     and where does your EDIT of it live?
  3. Why does 'the container's /tmp' not mean anything to the kernel's
     path resolution outside the mount namespace?

  PREDICTION for 06-pivot_root.sh: pivot_root swaps the rootfs. Does it
  change WHICH kernel you talk to? (Careful — this is the setup for the
  whole act2 punchline.)

  Next: act1-build-the-jail/06-pivot_root.sh
EOF
