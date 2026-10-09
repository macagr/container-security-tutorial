# Act 4 — The matrix: technique × capability × remediation

This is the takeaway people photograph. Fill every cell as acts 1–3 get
implemented; each script's "check question" output feeds a row here.

## The matrix (to be completed)

| Technique | Trigger event | Knob / file it abuses | Capability needed | Path resolution trick | Remediation that kills it | Kubernetes mapping |
|---|---|---|---|---|---|---|
| core_pattern   | process dumps core         | /proc/sys/kernel/core_pattern | CAP_SYS_ADMIN (write /proc/sys) | payload at host-visible path | masked/ro /proc/sys | PodSecurity restricted + maskedPaths |
| uevent_helper  | kernel uevent             | /sys/kernel/uevent_helper     | CAP_SYS_ADMIN (write /sys)      | payload at host-visible path | masked/ro /sys | PodSecurity restricted + maskedPaths |
| binfmt_misc   | exec of unknown format     | /proc/sys/fs/binfmt_misc/*    | CAP_SYS_ADMIN (register)        | interpreter path in init mnt ns | don't mount binfmt_misc | (no default mount in containers) |
| release_agent | cgroup becomes empty       | <cgroup v1>/release_agent     | CAP_SYS_ADMIN + writable v1 hierarchy | payload at host-visible path | cgroup v2 (kernel-level) + /sys ro | cgroup v2 default on modern k8s |

## Reading the matrix

- The "capability needed" column IS the argument for dropping capabilities:
  no single technique needs more than CAP_SYS_ADMIN + a writable knob path.
- The "path resolution trick" column is act2's bridge made permanent:
  every technique needs a way for the INIT mount namespace to see your file.
  This is also why hostPath volumes are prized findings (they hand you a
  host path by design).
- The "Kubernetes mapping" column is the bridge to act5: these are exactly
  the misconfigurations a cluster scanner should flag (privileged pods,
  writable host paths, hostPID/hostNetwork, unmasked /proc and /sys).

## TODO: fill cells from measured results (actual caps, actual errors)
