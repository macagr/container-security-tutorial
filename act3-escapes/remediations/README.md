# Remediations

One remediation per escape. Each is applied AFTER a successful escape
(beat 3) so attendees watch the technique die, and understand why at the
kernel level.

| Remediation script | Blocks | Kernel-level reason |
|---|---|---|
| `core_pattern.sh`    | core_pattern        | /proc/sys mounted read-only or masked — the knob can no longer be written, no matter the capability |
| `uevent_helper.sh`  | uevent_helper       | /sys masked/ro in the container mount table |
| `binfmt_misc.sh`    | binfmt_misc         | binfmt_misc not mounted inside the container (or write-protected) — nothing to register |
| `release_agent.sh`  | release_agent       | cgroup v2 (no release_agent file) + no writable cgroup v1 hierarchy + /sys ro |
| `capabilities.sh`   | ALL techniques     | dropping CAP_SYS_ADMIN (and friends) removes the write access the knobs need in the first place — the foundational fix |
| `seccomp.sh`        | (gap demonstration) | show why seccomp alone does NOT stop these: the syscalls used are permitted ones (open/write on dangerous paths) — seccomp is necessary, not sufficient |

## How each remediation script works

1. Print the container's current view of the knob (before)
2. Apply the remediation (masked mount, ro remount, capability drop)
3. Print the view again (after) — knob gone or read-only
4. Prompt the attendee to re-run the corresponding act3 escape and
   observe EPERM/EROFS/ENOENT — and say WHICH error and WHY
5. Map to Kubernetes: which Pod Security Standards level / securityContext
   field delivers this remediation in a real cluster (the bridge to act5)

## TODO: implement each script; each one must be runnable standalone and
## always restore the pre-lab state on exit (idempotency + cleanup trap).
