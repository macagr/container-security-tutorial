# Blowing up containers: lab repository (cgroup v2 branch)

A learning repository for container security: build a container **from
scratch, without Docker**, then exploit the kernel's usermode helper escape
hatches, applying one remediation after each escape. Every technique is
well-documented public knowledge (Trail of Bits, container-security.dev,
kernel docs); this repo's contribution is structure — the same material as
a paced, two-terminal, hands-on lab.

This branch targets **cgroup v2** (the modern default on current
distributions and Kubernetes). On a cgroup v1 machine, use the `cgroup-v1`
branch: it shows release_agent working before its death. Here, release_agent
is already extinct, and the lab makes that absence the lesson.

## Intended audience

- **Platform engineers and cluster admins** who configure `securityContext`
  and want to understand *why* each hardening field exists.
- **Security professionals** reviewing Kubernetes clusters who want the
  kernel-level mechanics behind "privileged containers are dangerous,"
  not just the rule.
- **Curious engineers** comfortable with a Linux shell but with no
  prerequisite knowledge of namespaces, cgroups, or capabilities — the lab
  builds every concept from the ground up, and each script's beats assume
  only that you can read its output.

You need: an Ubuntu machine (or VM) you can break, sudo, and two terminals
side by side. You do NOT need: prior container internals, Kubernetes
experience, or a compiler.

## Attribution

This repository's code and scripts were developed with the support of AI
agents (Factory Droid), working interactively with the authors: the lab's
structure, beats, and pedagogical framing were designed by the authors and
reviewed script by script; the AI assistance covered drafting, tooling
plumbing, and iteration on the scripts themselves. Verify all technical
claims against the kernel documentation and the referenced sources.

## The two-terminal convention

- **Terminal A = "host"**: your normal root shell. This is where escapes land.
- **Terminal B = "lab"**: where you become the container.

Every script prints which terminal it belongs in. Keep them side by side:
watching the escape appear in Terminal A *is* the lesson.

## Layout

| Directory | What you do |
|---|---|
| `setup/` | One-time machine checks and package installs |
| `act1-build-the-jail/` | Build a container from nothing: namespaces, cgroups, capabilities, overlayfs, pivot_root, seccomp |
| `act2-escape-hatches/` | Understand usermode helpers and why paths resolve outside your container |
| `act3-escapes/` | core_pattern, uevent_helper, binfmt_misc, release_agent — each paired with a remediation |
| `act4-matrix.md` | The takeaway: technique × capability × remediation |
| `act5-cluster/` | Find these misconfigurations at cluster scale with kind + kube-dementor |

## Build rules

1. Every script is idempotent: re-running never breaks state.
2. Every script opens with "what you should see" and closes with a check
   question. If the check fails, something did not isolate — stop and read.
3. No network needed except `setup/01-packages.sh` and `act5-cluster/`.

## Status

All scripts implemented. Pattern per script: persistent [INSIDE] shells,
beats with observations in BOTH terminals, predictions before each act,
residue checks and cleanup traps, check questions before moving on.

Tested on: Ubuntu 24.04.5 LTS arm64, kernel 7.0.0-31-generic, cgroup v1
(grub toggle applied via setup/02-cgroup-mode.sh).

Two pin points remain as TODOs:
- `act5/02-kube-dementor.sh`: fill KDM_VERSION + KDM_INSTALL_CMD from the
  kube-dementor releases (separate repo); verify arm64 binary exists.
- `act5/01-kind.sh`: re-pin K8S_NODE_VER when the lab is re-tested.

Environment notes: the [INSIDE] prompt marker exists to prevent running
escapes in the host terminal; scripts are idempotent and restore any knob
they touch (core_pattern, uevent_helper, binfmt registrations) via traps.
