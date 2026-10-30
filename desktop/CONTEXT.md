# CONTEXT.md — nixos/desktop

Domain glossary for this NixOS flake. Implementation-free — how we name things, not how we build them.

## Terms

### Portable module
A module (`.nix` file or directory) that carries no assumptions about specific hardware, hostnames, or UUIDs. Can be dropped into another machine's flake and work, or require only a small adapter.

### Hardware-locked module
A module tied to specific hardware (GPU model, audio interface, disk UUIDs, peripherals). Must live behind a clear seam so portable modules never depend on it.

### Opinionated module
A module representing a deliberate, swappable choice — a desktop environment, shell, editor, or workflow tool the user is actively evaluating. Isolated so it can be replaced without touching the rest of the config.

### Live-lane dotfile
A config file symlinked to the repo checkout (not the Nix store) via `mkOutOfStoreSymlink`. Hand-edits hot-reload; GUI writes land as git diffs. Dangles harmlessly if the repo isn't checked out at the expected path.

### Stable-lane dotfile
A config file copied into the Nix store at build time. Requires a rebuild to change. Used for configs that are set-and-forget or that must not be accidentally mutated.

### Separate home (trial)
The `@nixos-home` btrfs subvolume is mounted at `/home` by the trial NixOS
install, while CachyOS keeps its own `@home`. Home Manager owns the NixOS home
independently; the two OSes do not share `~`.

## Principles

### Portability-first file separation
Modules are separated by *portability*, not by topic. The goal: be able to cherry-pick modules for a different machine (or the homebrew dev/quickstart project) without dragging in hardware-specific or opinionated choices.

### Consolidation over fragmentation
Prefer fewer, cohesive files over many tiny ones. A 6-line file that exists only to be imported is overhead. Merge into the nearest cohesive neighbour unless isolation is load-bearing (hardware-locked or opinionated).

### Opinionated isolation
Choices the user is actively trying out (niri/noctalia, herdr, etc.) should be isolated so they can be swapped without cascading changes. This is the one case where a small standalone file earns its keep.
