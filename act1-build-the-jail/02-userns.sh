#!/usr/bin/env bash
# act1/02-userns.sh — user namespaces: "I'm root, but fake."
# Terminal: lab (B). NO sudo — deliberately unprivileged, contrasting with 01.
#
# Same pattern as 01: the script drops you INTO live namespace shells with
# the [INSIDE] prompt, you run the observation commands, compare with
# Terminal A, and 'exit' when done.
#
# What you should see: uid 0 inside, your real uid outside — and a hard
# wall the moment you touch something owned by the INIT user namespace.
# That wall is the seed of the whole talk: "root in a container" is not
# one kind of root.

set -euo pipefail

hr()   { printf '\n\033[1m%s\033[0m\n' "----------------------------------------------------------------"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
say()  { printf '  %s\n' "$*"; }
pause(){ printf '\n  \033[2m[press Enter for the next beat]\033[0m'; read -r; }
INSIDE_PROMPT='\[\033[35m\][INSIDE]\[\033[0m\] \$ '

REAL_UID=$(id -u); REAL_NAME=$(id -un)

# No sudo here. This is the point of the script.
enter() { env PS1="$INSIDE_PROMPT" unshare "$@" bash; }

# --------------------------------------------------------------------------
hdr "BEAT 0 — your prediction from 01-namespaces.sh"
hr
say "Beat 6 asked: what will 'id' show inside unshare -U?"
say "Commit to an answer before running beat 1."
pause

# --------------------------------------------------------------------------
hdr "BEAT 1 — unshare -U: a user namespace with no mapping (yet)"
hr
say "Entering a user namespace with NO uid mapping. Run inside:"
say "    id"
say "Then in Terminal A:"
say "    id"
say "You expected root. Look closely at what you got."
say "Type 'exit' to come back."
hr
enter -U
say "debrief: uid 65534 (nobody). The kernel gave you a namespace, but no"
say "ids are mapped into it. Root is not a fact about you — it is a"
say "RELATIONSHIP between you and a user namespace."
pause

# --------------------------------------------------------------------------
hdr "BEAT 2 — the mapping: where fake root comes from"
hr
say "Now you map your outside uid to inside uid 0 — by hand, because the"
say "shortcut (--map-root-user) is just these two file writes. Run inside:"
say "    echo deny > /proc/self/setgroups"
say "    echo '$REAL_UID 0 1' > /proc/self/uid_map"
say "    cat /proc/self/uid_map"
say "    id"
say "    whoami"
say "Then in Terminal A:"
say "    id           → the outside you is untouched"
say "Type 'exit' to come back."
hr
enter -U
say "debrief: uid_map line '$REAL_UID 0 1' says: 'inside this namespace,"
say "uid 0 IS outside uid $REAL_UID'. --map-root-user writes these files"
say "for you. Nothing about the outside world changed."
pause

# --------------------------------------------------------------------------
hdr "BEAT 3 — fake root has REAL power... inside its own world"
hr
say "Inside a userns you hold a full capability set, scoped to objects that"
say "belong to it. In 01 you needed sudo for these. Now you don't."
say "(Note the -r flag: beat 2's mapping, applied automatically — you now"
say " know exactly what it does.)"
say "Run inside:"
say "    id                               (uid 0 — mapped from YOUR uid)"
say "    mount -t tmpfs tmpfs /mnt        (worked WITHOUT sudo)"
say "    grep ' /mnt ' /proc/mounts"
say "    capsh --print                    (a full-looking set, if libcap2-bin is installed)"
say "Then in Terminal A:"
say "    grep ' /mnt ' /proc/mounts       (your tmpfs: invisible outside)"
say "Type 'exit' to come back."
hr
enter -Urmr
say "debrief: the capabilities are real but namespaced — power only over"
say "objects belonging to this user namespace."
pause

# --------------------------------------------------------------------------
hdr "BEAT 4 — the wall: fake root meets the REAL kernel"
hr
say "Same fake-root world, one new step. /proc/sys/kernel/core_pattern is"
say "owned by the INIT user namespace. Run inside:"
say "    id"
say "    echo x > /proc/sys/kernel/core_pattern"
say "Read the refusal carefully — then in Terminal A confirm the file is"
say "untouched:"
say "    cat /proc/sys/kernel/core_pattern"
say "Type 'exit' to come back."
hr
enter -Ur
say "debrief: uid 0 in a userns holds ZERO power over the init namespace."
say "→ REMEMBER THIS FILE. In act3 we DO write it — from a PRIVILEGED"
say "  container, which keeps REAL root, REAL capabilities, and skips the"
say "  user namespace wall entirely. That skipped wall is the attack surface."

# --------------------------------------------------------------------------
hdr "RESIDUE CHECK (automatic)"
say "tmpfs on /mnt visible on the host: $(grep -c ' /mnt ' /proc/mounts || true)"
say "core_pattern (should be unchanged): $(cat /proc/sys/kernel/core_pattern)"

hdr "CHECK QUESTIONS (act1/02) — answer before moving on"
cat <<'EOF'
  1. After unshare -U with no mapping, why does 'id' show nobody (65534)?
  2. What exactly does --map-root-user do? (Two files. Name them.)
  3. Inside unshare -Urm you mounted a tmpfs without sudo. Does a user
     namespace make sudo unnecessary? What is the catch?
  4. Fake root could not write core_pattern. What kind of container CAN?

  PREDICTION for 03-cgroups.sh: cgroups limit resources, not views. Do you
  expect a cgroup to change what you can SEE, or only what you can USE?

  Next: act1-build-the-jail/03-cgroups.sh
EOF
