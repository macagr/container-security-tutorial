#!/usr/bin/env bash
# act3/remediations/seccomp.sh — the gap demonstration, NOT a fix.
# Shows concretely why a syscall filter cannot stop the act3 techniques:
# seccomp sees syscall names, not paths.
set -euo pipefail
echo "  The two writes that would matter to an attacker:"
echo "    open(\"/proc/sys/kernel/core_pattern\", O_WRONLY)"
echo "    open(\"/etc/hostname\", O_WRONLY)"
echo "  Same syscall (openat). Same arg count. Any seccomp profile that allows"
echo "  writing /etc/hostname ALSO allows writing core_pattern. The filter"
echo "  cannot tell them apart — it never reads the string."
echo ""
echo "  What seccomp DOES stop (different attack classes):"
echo "    kexec_load (kernel replacement), bpf (filter injection),"
echo "    kernel modules via finit_module, ptrace against host processes"
echo "  — that is why the default profile exists and why you keep it."
cat <<'EOF'
  The honest summary, in one sentence:
    seccomp is NECESSARY (blocks other classes) but NOT SUFFICIENT (blind
    to paths) — pair it with capability drops (who can write) and mount
    masking (what is visible to write), which is exactly what the
    restricted Pod Security Standard does.

  Kubernetes mapping:
    securityContext.seccompProfile: type: RuntimeDefault   (the default profile)
    ...in ADDITION to caps/masking, never instead of them.
EOF
