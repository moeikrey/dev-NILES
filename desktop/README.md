# NixOS Desktop

My NixOS config — niri (Wayland compositor) + noctalia (shell) on an AMD/NVIDIA desktop.

Trial-installs alongside CachyOS on the 55 GB `NIX` btrfs drive: `@nixos`
for `/`, `@nixos-home` for `/home`, and the shared ESP. CachyOS's Limine stays
in charge; NixOS installs no bootloader. See
[`../docs/install-doom-fatal.md`](../docs/install-doom-fatal.md).

## What's in it

| Module | What it does |
|---|---|
| `configuration.nix` | Base system — networking and Nix settings |
| `identity.nix` / `modules/identity.nix` | Host user, home directory, hostname, git author, user creation, and rebuild sudo access |
| `modules/boot.nix` | No bootloader (CachyOS's Limine stays in charge), kernel selection, zram |
| `modules/desktop.nix` | niri + greetd autologin, PipeWire, polkit, Nautilus |
| `modules/gaming.nix` | Steam, Gamescope, etc. |
| `modules/cli.nix` | CLI tools |
| `modules/fonts.nix` | Fonts (including Apple SF via flake input) |
| `modules/ssh.nix` | Optional SSH service (not imported by default) |
| `home.nix` | Home Manager — packages and the dotfiles it manages |
| `configs/` | App configs (niri, noctalia, fish, fuzzel, etc.) |
| `modules/hardware.nix` | Machine-specific: filesystems, GPU, bluetooth |

## Trying this config

For a full new-host deployment guide, see [`../docs/getting_started.md`](../docs/getting_started.md).

### 1. Generate your hardware config

From a NixOS installer or existing install:

```bash
nixos-generate-config --show-hardware-config > modules/hardware.nix
```

Replace the checked-in `modules/hardware.nix` with yours. You'll need to keep or adapt:

- The btrfs subvolume layout (`@nixos` for `/`, `@nixos-home` for `/home`) — or flatten to whatever you use
- The NVIDIA block if you have a different GPU (or remove it)
- The bluetooth section if you don't need it

### 2. Adapt Bootloader Settings

This trial keeps CachyOS's Limine and installs no NixOS bootloader:
`modules/boot.nix` disables GRUB, systemd-boot and Limine and sets
`canTouchEfiVariables = false`. Stage the kernel/initrd on the ESP and add the
entry by hand — see [`../docs/install-doom-fatal.md`](../docs/install-doom-fatal.md).

If you want NixOS to own the ESP instead, replace that block with your
bootloader settings:

```nix
{...}: {
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  zramSwap.enable = true;
}
```

### 3. Build

```bash
cd desktop
sudo nixos-rebuild switch --flake .#NixIsland
```

Or use `rebuild.sh`, which also formats with `alejandra`, shows the Nix diff, compares the build with `nvd`, switches, and commits with the `nvd` output in the commit body:

```bash
./rebuild.sh                          # auto-commits as "rebuild: <timestamp>"
./rebuild.sh "commit subject"         # custom commit message
```

### 4. First login

The config autologins as the user in `identity.nix` via greetd → niri-session.
On first boot, set a real password:

```bash
passwd
```

(The `initialPassword` in `modules/identity.nix` only applies when the user is first created.)

## Dual-boot notes

This trial does not enable `boot.loader.limine`; CachyOS's Limine stays in
charge and the NixOS entry is added by hand. `desktop/sync-limine.sh` refreshes
the kernel/initrd copies on the ESP after a kernel change.

The upstream config instead had NixOS own Limine on the ESP via
`boot.loader.limine`, with CachyOS and Windows as extra entries. If you switch
to that model, the generated config lives under `/boot/limine/limine.conf`, and
`boot.loader.timeout = 1` controls the menu timeout. The native generator also
writes its own `default_entry` for the newest NixOS generation, so avoid adding
another `default_entry` in `boot.loader.limine.extraConfig` unless you have
verified how duplicate Limine keys are resolved.
