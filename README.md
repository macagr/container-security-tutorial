# Blowing up containers — lab repository

A learning repository for container security: build a container **from
scratch, without Docker**, then exploit the kernel's usermode helper escape
hatches, applying one remediation after each escape.

## Pick your branch (one command)

    stat -fc %T /sys/fs/cgroup

- `tmpfs`     → you are on **cgroup v1**: `git checkout cgroup-v1`
- `cgroup2fs` → you are on **cgroup v2**: `git checkout cgroup-v2`

The branches are identical except for the cgroup-dependent material
(`act1/03`, `act3/04`, and the setup checks): the v1 branch shows the
release_agent technique work and then die; the v2 branch shows it extinct
by kernel design. Everything else — namespaces, user namespaces,
overlayfs, pivot_root, seccomp, three live escapes, and the cluster
scanner act — is the same on both.

## Attribution

This repository's code and scripts were developed with the support of AI
agents (Factory Droid), working interactively with the authors: the lab's
structure, beats, and pedagogical framing were designed by the authors and
reviewed script by script; the AI assistance covered drafting, tooling
plumbing, and iteration on the scripts themselves. Verify all technical
claims against the kernel documentation and the referenced sources.
