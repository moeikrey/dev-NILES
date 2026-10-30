# Getting Started

This guide adapts the `desktop` flake to a new machine. It assumes you are
either booted into a NixOS installer or an existing NixOS system with the
target filesystems mounted, or, to try it without giving up your current
distro, running an existing Linux install on btrfs (see
[Trying it alongside an existing install](#trying-it-alongside-an-existing-install)).

For what each module actually does, see
[`../desktop/README.md`](../desktop/README.md).

## 1. Put the checkout at `~/nixos`

The live-lane Home Manager dotfiles point at `~/nixos/desktop/configs` so
their edits can hot-reload and remain in the checkout. Clone the repository at
that location before the first switch.

The config lives on the `nixos` branch (the default) of `NoahIles/dev`:

```bash
git clone https://github.com/NoahIles/dev.git ~/nixos
cd ~/nixos/desktop
```

Or fork it:

```bash
gh repo fork NoahIles/dev --fork-name nixos --default-branch-only --clone=false
git clone "git@github.com:$(gh api user -q .login)/nixos.git" ~/nixos
cd ~/nixos/desktop
```

## 2. Set the host identity

Edit `desktop/identity.nix` before building:

```nix
rec {
  username = "your-user";
  homeDirectory = "/home/${username}";
  fullName = "Your Name";
  email = "you@example.com";
  hostName = "nixos";
  sshKeys = ["ssh-ed25519 AAAA... you@example.com"];
}
```

These values configure the NixOS user, Home Manager user, the user
noctalia-greeter preselects at login, sudo permission for `nixos-rebuild`,
`networking.hostName`, the git author name/email, and SSH authorized keys.
Keep the UID in `modules/identity.nix` aligned with any existing account when
sharing a home directory with another OS.

`initialPassword` is set to the username only for the first account creation.
Set a real password immediately after boot with `passwd`, or replace it before
deployment.

## 3. Remove machine-specific services you do not want

SSH is optional. To omit the checked-in keys and the OpenSSH service, remove
this line from the `sharedModules` list in `desktop/flake.nix`:

```nix
./modules/ssh.nix
```

Removing the import is sufficient; keeping the unused module file does not
affect the evaluated configuration. If you keep it, replace the authorized
keys and review the configured port and authentication settings.

Also review the modules included only by the bare-metal `NixIsland` target:

- `modules/hardware.nix` for storage, GPU, Bluetooth, and peripherals.
- `modules/boot.nix` for the Limine and shared-ESP setup.
- `modules/gaming.nix` and `modules/wootility.nix` for optional desktop
  hardware and workflow choices.
- `modules/kokoro-tts.nix` for the Claude Code TTS hooks; it expects Python
  venvs under `~/.claude/hooks/` that the repo doesn't create.

## 4. Generate the hardware configuration

Replace `desktop/modules/hardware.nix` with one generated for the
target machine:

```bash
nixos-generate-config --show-hardware-config > desktop/modules/hardware.nix
```

Then add back only the settings required by the target, such as its filesystem
layout, CPU microcode, graphics driver, and peripherals. Do not carry over the
checked-in disk UUIDs, btrfs subvolumes, NVIDIA settings, sensor module, or
Bluetooth device assumptions.

## 5. Choose a bootloader

The checked-in `modules/boot.nix` is a trial setup: it disables GRUB,
systemd-boot and Limine so the host's existing bootloader (CachyOS's Limine)
stays in charge, and the NixOS entry is added by hand. See
[`install-doom-fatal.md`](install-doom-fatal.md) for the exact steps.

If you want NixOS to own the ESP instead, replace `modules/boot.nix` with the
appropriate bootloader configuration (or restore the upstream Limine module).

## 6. Validate and deploy

From `~/nixos/desktop`, evaluate the configurations and build the target
before switching to it:

```bash
nix flake check
nixos-rebuild build --flake .#NixIsland
sudo nixos-rebuild switch --flake .#NixIsland
```

For later changes, use `./rebuild.sh`. It formats with alejandra, commits
**every tracked change** in the repo as a work commit, builds, switches, then
adds an empty `rebuild: gen N` commit recording the generation (see
`docs/adr/0001-two-commit-rebuild-protocol.md`). Don't run it until the
host-specific changes above are done, and check `git status` first.

## Trying it alongside an existing install

This is how `NixIsland` itself started: NixOS installed from a running
CachyOS into a new subvolume on the same btrfs filesystem, without a USB
installer or repartitioning. Nothing on the host's root subvolume changes, and
removing it later means deleting one subvolume and one boot entry.

You need root, Nix with flakes enabled on the host, and a btrfs root. Run
these commands as root on the host. `/dev/sdXN` is the btrfs partition and
`/dev/sdXE` is the ESP.

### Create and mount the subvolume

```bash
mkdir -p /mnt/top && mount /dev/sdXN /mnt/top     # top level (subvolid=5)
btrfs subvolume create /mnt/top/@nixos
btrfs subvolume create /mnt/top/@nixos-home       # see "Home" below

mkdir -p /mnt/nixos && mount -o subvol=@nixos /dev/sdXN /mnt/nixos
mkdir -p /mnt/nixos/{home,boot}
mount -o subvol=@nixos-home /dev/sdXN /mnt/nixos/home
mount /dev/sdXE /mnt/nixos/boot
```

**Home.** A separate `@nixos-home` is the safe choice for a trial. If you
share the host's home subvolume instead (this repo does: both OSes mount
`@home`), Home Manager writes into it, the live-lane dotfiles replace
`~/.config/{niri,fish,noctalia,...}` with symlinks into the checkout, and the
host sees all of it. Any file in the way is renamed to `*.hm-bak`. Sharing
home also needs the same UID on both systems (`modules/identity.nix`).

### Generate hardware config and install

```bash
nix shell nixpkgs#nixos-install-tools
nixos-generate-config --root /mnt/nixos --show-hardware-config \
  > ~/nixos/desktop/modules/hardware.nix
```

Check that the generated `fileSystems` entries include `subvol=@nixos` and
`subvol=@nixos-home` before going further. Then make the steps above apply
to this machine (identity, hardware, and drop `boot.nix` for now; see the
next section). Then install:

```bash
cd ~/nixos/desktop
nixos-install --root /mnt/nixos --flake .#NixIsland --no-root-passwd
```

New `.nix` files must be `git add`ed first: flakes ignore untracked files.

### Booting it

The safest trial leaves the host's bootloader in charge, so NixOS doesn't
touch the ESP or EFI boot order. Leave `modules/boot.nix` out and set
`boot.loader.grub.enable = false;` instead, then add an entry to the host
bootloader that uses NixOS's stable `init` path, so it survives rebuilds:

```
cmdline: rw rootflags=subvol=@nixos root=UUID=<btrfs uuid> init=/nix/var/nix/profiles/system/init
```

The kernel and initrd live under `/nix/store` inside `@nixos`:

```bash
readlink -f /mnt/nixos/nix/var/nix/profiles/system/kernel
readlink -f /mnt/nixos/nix/var/nix/profiles/system/initrd
```

- **GRUB** reads btrfs, so it can point at them directly
  (`/@nixos/nix/store/...`).
- **Limine and systemd-boot** only read the ESP, so copy both files there
  (for example to `/boot/nixos/`) and point the entry at the copies. Sign the
  kernel with `sbctl` if Secure Boot is on.

The copy needs redoing whenever the kernel or initrd changes after a rebuild
(always for a kernel bump, sometimes for other changes). Once you commit to
NixOS, hand the bootloader to NixOS the way `modules/boot.nix` does and drop
the manual entry.

### Removing it

Delete the boot entry and any kernel copies on the ESP, then
`btrfs subvolume delete /mnt/top/@nixos /mnt/top/@nixos-home`.

## Gotchas

### Live dotfile symlinks require the checkout path

The `live` helper in `desktop/modules/home/dotfiles.nix` uses
`mkOutOfStoreSymlink` to symlink `~/.config/<app>` to the repo checkout so
hand-edits hot-reload without a rebuild. This requires a **string** containing
the real filesystem path -- not a Nix path expression.

In flake mode, any Nix path (e.g. `../../configs`) is copied into
`/nix/store` at eval time. `builtins.toString` on that path gives you the
store path, not the original location on disk. Flakes are pure by design --
there is no built-in way for a flake to discover where its own source lives.

This means `configsDir` uses the conventional checkout location:

```nix
configsDir = "${config.home.homeDirectory}/nixos/desktop/configs";
```

If the repo moves from `~/nixos`, update this string. Alternatives
(`--impure` + `builtins.getEnv`, passing the path via `specialArgs` from
`rebuild.sh`) exist but aren't worth the complexity unless the repo location
actually varies.

**Symptom if broken:** apps like fish spam `Read-only file system (os error
30)` because their config dir points into `/nix/store`.
