#!/usr/bin/env bash
# act1/07-seccomp.sh — a minimal syscall filter; the last wall of the jail.
# Terminal: lab (B). Uses sudo (python3 + systemd present on Ubuntu 24.04).
#
# Beats:
#   1. STRICT mode (the original 2005 seccomp): 4 syscalls, and 'ls' dies
#   2. FILTER mode (BPF profiles, what containers actually use) via systemd
#   3. THE GAP: seccomp sees syscall NAMES, not paths — why it cannot stop
#      the act3 techniques alone (necessary, not sufficient)
#
# CLEANUP: all demos run in short-lived processes; nothing persists.

set -euo pipefail

hr()   { printf '\n\033[1m%s\033[0m\n' "----------------------------------------------------------------"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
say()  { printf '  %s\n' "$*"; }
pause(){ printf '\n  \033[2m[press Enter for the next beat]\033[0m'; read -r; }

command -v python3 >/dev/null || { say "python3 required for beat 1"; exit 1; }

# --------------------------------------------------------------------------
hdr "BEAT 0 — your prediction from 06-pivot_root.sh"
hr
say "Does a syscall filter inspect PATHS or NAMES? Commit before beat 3."
pause

# --------------------------------------------------------------------------
hdr "BEAT 1 — strict mode: four syscalls, no appeals"
hr
say "The original seccomp: PR_SET_SECCOMP + SECCOMP_MODE_STRICT allows only"
say "read, write, exit, sigreturn. Everything else: SIGSYS, process dies."
say "Run (the script does it — watch):"
hr
python3 - <<'PYEOF'
import ctypes, os
libc = ctypes.CDLL(None, use_errno=True)
PR_SET_SECCOMP = 36
SECCOMP_MODE_STRICT = 1
r = libc.prctl(PR_SET_SECCOMP, SECCOMP_MODE_STRICT, 0, 0, 0)
print("  prctl(PR_SET_SECCOMP, STRICT) →", "OK" if r == 0 else "FAILED")
print("  this print is a write() — allowed. Now exec /bin/ls ...")
os.execv("/bin/ls", ["ls", "/"])
PYEOF
say "↑ Killed. execve is not in the allowed four — the process died mid-sentence."
say "In Terminal A: dmesg | tail -3   (seccomp audit line, on the record)"
pause

# --------------------------------------------------------------------------
hdr "BEAT 2 — filter mode: the BPF profiles containers ship"
hr
say "Strict mode is useless for real software. Real seccomp is a BPF filter"
say "over syscall NAMES with argument COUNTS — exactly what a container's"
say "profile is. You get one via systemd's SystemCallFilter (same mechanism"
say "the kubelet/runtime uses under the hood):"
say ""
say "You are about to be dropped into a shell where the @clock syscall group"
say "is DENIED. Run inside:"
say "    date                (clock_gettime → SIGSYS, dies)"
say "    ls /                (file syscalls: fine)"
say "Type 'exit' to come back."
hr
systemd-run --pty --same-dir -p SystemCallFilter=~@clock bash
say "debrief: a LIST of names, enforced per-syscall. Docker's default profile"
say "denies ~44 syscalls (kexec_load, bpf, keyctl...). It is a denylist of"
say "DANGEROUS SYSCALLS — keep that phrasing for beat 3."
pause

# --------------------------------------------------------------------------
hdr "BEAT 3 — THE GAP: names, not paths"
hr
say "Now answer the prediction. Watch two opens side by side:"
say "    open(\"/etc/hostname\", O_WRONLY)          (innocent)"
say "    open(\"/proc/sys/kernel/core_pattern\", O_WRONLY)   (act3's whole crime)"
say "Same syscall. Same argument count. Same seccomp verdict: ALLOW."
say ""
say "Seccomp CANNOT tell them apart without reading the pointer's memory —"
say "and even argument filters only see the pointer VALUE, not the string."
say ""
say "→ That is why act3's remediations combine FOUR tools, not one:"
say "    capabilities    (WHO can open privileged things)"
say "    mount masking   (the path is not THERE to open)"
say "    seccomp         (the syscall class is denied — blocks other classes)"
say "    AppArmor        (the one that DOES read paths — next act)"
say "Necessary, not sufficient. This is the sentence to remember."
pause

# --------------------------------------------------------------------------
hdr "CHECK QUESTIONS (act1/07) — act 1 is complete"
cat <<'EOF'
  1. In strict mode, why did the print work but the exec die? (Name both
     syscalls and their verdicts.)
  2. Your prediction: was it right? Would ANY filter configuration stop
     'open /proc/sys/kernel/core_pattern' without also stopping 'open
     /etc/hostname'? Why not?
  3. Act 1 recap in one sentence: a container is namespaces (____), cgroups
     (____), capabilities (____), overlayfs (____), pivot_root (____), and
     seccomp (____). Fill the blanks with what each LIMITS.

  Act 2 begins: act2-escape-hatches/01-usermode-helpers.sh
  Everything you built in act 1 has one thing in common: it constrains YOU.
  Act 2 asks: what constraints does the KERNEL obey? (Spoiler: not yours.)
EOF
