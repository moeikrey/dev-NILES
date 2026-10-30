# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Noah's personal NixOS config, forked from vimjoyer's flake-starter-config. The
root `flake.nix` is a **template registry only** — it has no `nixosConfigurations`
of its own. Each top-level folder (currently just `desktop/`) is a
self-contained flake with its own `flake.nix`/`flake.lock` and is the thing
actually built.

## Workflow

Work in a worktree, merge into `nixos` when done. Every commit on `nixos`
must evaluate cleanly (`nix eval .#nixosConfigurations.NixIsland...`, run from `desktop/`). `vm`
is `sharedModules ++ [./vm.nix]` (see `desktop/flake.nix`) — identical
modules to `desktop` otherwise, so a `desktop` eval covers `vm` too,
*except* where behavior is conditioned on the `_isVM` HM arg (currently
just `modules/home/dotfiles.nix`) or on options `vm.nix` overrides with
`lib.mkForce` (`hardware.nvidia.modesetting.enable`,
`services.xserver.videoDrivers`, `hardware.bluetooth.enable`,
`boot.loader.systemd-boot.enable`, `fileSystems."/"`). Only re-check
`.vm...` when a change touches one of those, or `vm.nix` itself. Noah
handles pushing.

```bash
cd ~/nixos/desktop && ./rebuild.sh                     # format, commit, build, switch, record gen
cd ~/nixos/desktop && ./rebuild.sh "subject" "body"    # same, with a custom work-commit message
nixos-rebuild build --flake .#NixIsland                # build only, no root needed
alejandra -q .                                         # format *.nix (rebuild.sh does this)
```

**Run `rebuild.sh` yourself when a rebuild or switch is asked for.**
`sudo nixos-rebuild` is NOPASSWD (`desktop/modules/identity.nix`), so the
script's sudo works from an agent shell. Never hand-roll the build + switch
(e.g. `pkexec nixos-rebuild switch`): that skips the generation record
commit, and the pkexec prompt can't be answered remotely.

What `rebuild.sh` does (two-commit protocol, see
`docs/adr/0001-two-commit-rebuild-protocol.md`): format with alejandra, then
`git commit -a` every tracked change as the work commit (`wip: <timestamp>`
unless a subject is given), build, print `nvd diff`, `sudo nixos-rebuild
switch --store-path`, then add an empty `rebuild: gen N` commit holding the
shortlog and nvd diff. It also runs on a clean tree if HEAD moved since the
last rebuild. A failed build soft-resets the work commit. This trial config
installs no bootloader; `sync-limine.sh` refreshes the kernel/initrd copies on
the shared ESP after a kernel change.

**Check `git status` before running it.** Because it sweeps every tracked
change, stop and ask if the repo is mid-rebase/merge or has tracked edits
unrelated to the task. Live-lane configs drift on their own: e.g.
`niri-zen-toggle` rewrites `desktop/configs/niri/niri.kdl` (zen mode,
the `game_mode.kdl` include). That drift is expected: don't ask about it
or commit it; keep it out of the rebuild with
`git update-index --skip-worktree` and undo that afterwards.

There is no test suite or linter beyond `alejandra` formatting and
`nixos-rebuild`'s own evaluation/build.

### Repo rules (promoted from auto memory, 2026-09-19)

- **Never `git add -A` in this repo's automation.** Only already-tracked
  modifications may be staged automatically (`git commit -a`, `git add -u`).
  Noah adds new files by hand on purpose: flakes ignore untracked files, so a
  new `.nix` file failing the build is the intended signal, not something
  tooling should paper over.
- **Don't pass a commit message through `just rebuild`.** The recipe
  interpolates `{{ args }}` unquoted, so a multi-word subject or body is
  word-split, and the failure only surfaces *after* the commit exists. Call the
  script directly: `cd ~/nixos/desktop && ./rebuild.sh "subject" "body"`.
- **A new worktree may start from a stale tree.** `origin/nixos` lags local
  `nixos` by a lot, since Noah pushes rarely, and `EnterWorktree` branches from
  the remote by default. Branch from local `nixos`, and re-run the eval on the
  merged tree before calling anything verified:
  `nix build --no-link --dry-run ./desktop#nixosConfigurations.NixIsland.config.system.build.toplevel`.

## Architecture

- **Bootloader**: this trial install boots via **CachyOS's Limine**. NixOS's
  `modules/boot.nix` disables GRUB, systemd-boot and Limine and sets
  `canTouchEfiVariables = false`; the ESP entry is added by hand (see
  `docs/install-doom-fatal.md`). `desktop/sync-limine.sh` refreshes the
  kernel/initrd copies after a kernel change. The upstream config used NixOS's
  native Limine module with sbctl Secure Boot; that is not active here.
- Desktop: noctalia (shell) on a choice of compositors, niri
  (`modules/niri.nix`) or umbriel (`modules/umbriel.nix`), picked at login by
  `noctalia-greeter` (`modules/desktop.nix`).

## Where things are documented

- `desktop/CONTEXT.md`: glossary for module boundaries (portable /
  hardware-locked / opinionated modules, live-lane vs stable-lane dotfiles,
  separate `@nixos-home`). Read before moving modules or dotfile ownership.
- `CONTEXT.md` (root): glossary for the Claude Code TTS setup only.
- `docs/adr/`: decisions (two-commit rebuild, live-lane Claude config).
- `desktop/configs/niri/CLAUDE.md`: niri/noctalia config layout.

## Testing in the VM

```bash
nix build ~/nixos/desktop#nixosConfigurations.vm.config.system.build.vm
NIX_DISK_IMAGE=<scratchpad>/vm.qcow2 ./result/bin/run-nixos-vm-vm   # fresh disk
ssh -p 2223 moeikrey@localhost   # enable ./modules/ssh.nix first
```

QEMU `screendump` fails ("no surface", GL display): log in via the monitor's
`sendkey`, then screenshot with `niri msg action screenshot-screen` over SSH.
State the desktop needs but the repo doesn't declare is tracked in
`docs/vm-undeclared-state.md`.

## Conventions

- `// ponytail:` comments mark deliberate simplifications/deferred work —
  read them before "fixing" something that looks incomplete.
- Don't rewrite unrelated generated dotfiles or machine-specific settings, and
  keep hardware-locked config out of portable modules (see
  `desktop/CONTEXT.md`).
- Format all `*.nix` with `alejandra` before committing.
