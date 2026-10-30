# Handoff — DOOM-FATAL trial NixOS install

Date: 2026-10-30
Status: **installed, not yet rebooted into**. CachyOS is still the default boot entry.

This document records what was done, the exact machine values, what was verified,
and what remains. Read it before touching the install.

---

## 1. Goal and constraints

- Try Noah's NixOS config **alongside CachyOS**, without repartitioning.
- Secure Boot is **off**; leave it off.
- **Keep the existing bootloader** (CachyOS's Limine). NixOS must not own or
  modify the ESP.
- Home lives on the drive mounted at `/nix` (`sdb4`).
- Regenerate `hardware.nix` for this machine.
- Remove SSH keys and ZeroTier.
- Install via `pkexec`.

---

## 2. Machine facts

| Item | Value |
|---|---|
| Hostname | `DOOM-FATAL` |
| User | `moeikrey`, UID/GID `1000`, GECOS `Andre` |
| Home | `/home/moeikrey` |
| Timezone | `America/Los_Angeles` |
| CPU | AMD Ryzen 7 9800X3D |
| Board | ASUS TUF GAMING B650E-E WIFI |
| GPU | NVIDIA RTX 3060 Ti (GA104) + AMD Radeon 610M iGPU |
| Ethernet | Realtek RTL8125 2.5GbE |
| Wi-Fi / BT | MediaTek MT7922 |
| Kernel | 7.3 (`linuxPackages_latest`) |
| NVIDIA driver | 595.104.02 stable, open modules |
| Current OS | CachyOS (Limine 12.9.4) |

`nixos-generate-config` could **not** run as the normal user
(`ERROR: Could not search B-tree: Operation not permitted`), so
`desktop/modules/hardware.nix` was written by hand from `lsblk`, `lspci`,
`lsmod`, and `/sys`.

---

## 3. Disk layout

| Mount | Device | Filesystem / subvolume | UUID |
|---|---|---|---|
| NixOS `/` | `/dev/sdb4` | btrfs `@nixos` | `b8f256a6-61d1-40e6-8cae-bd3b4c063caa` |
| NixOS `/home` | `/dev/sdb4` | btrfs `@nixos-home` | same |
| `/boot` | `/dev/nvme0n1p5` | vfat ESP, shared with CachyOS | `E452-3E68` |
| CachyOS `/` | `/dev/nvme0n1p4` | btrfs `@` | `366d4365-80ea-4054-a374-b9a2878a26d8` |

- The `NIX` drive is 55 GB. `@nixos` and `@nixos-home` already existed and were
  empty before the install.
- The Nix store lives **inside `@nixos`**. CachyOS's top-level store mounted at
  `/nix` is deliberately **not** reused.
- Home is **not** shared with CachyOS: `@nixos-home` is separate from CachyOS's
  `@home`.

---

## 4. Config changes made

All paths relative to the repo root `/nix/dev`.

| File | Change |
|---|---|
| `desktop/modules/hardware.nix` | Regenerated for DOOM-FATAL: btrfs subvol mounts, ESP, AMD microcode, `kvm-amd`, MT7922 Bluetooth, RTX 3060 Ti with NVIDIA 595 open modules. Removed the old 4080 / RodeCaster / Logitech / nct6687 / `linux_games` assumptions. |
| `desktop/modules/boot.nix` | Disables GRUB, systemd-boot and Limine; `canTouchEfiVariables = false`; no bootloader installed. Keeps `zramSwap`, `sysrq`, `linuxPackages_latest`. |
| `desktop/identity.nix` | `moeikrey`, `/home/moeikrey`, `Andre`, hostname `DOOM-FATAL`, `sshKeys = []`, placeholder email `moeikrey@localhost`. |
| `desktop/configuration.nix` | Removed ZeroTier service, its `wantedBy` override, and `NH_OS_FLAKE`; `stateVersion = "26.05"`. |
| `desktop/modules/identity.nix` | Removed the ZeroTier NOPASSWD `systemctl` rules; kept `nixos-rebuild` NOPASSWD. |
| `desktop/flake.nix` | Removed `./modules/ssh.nix` from imports. Flake attribute is still `NixIsland`. |
| `desktop/modules/ssh.nix` | Now unused; warning comment added (password auth is disabled, so enabling it needs keys). |
| `desktop/home.nix`, `desktop/vm.nix`, `desktop/rebuild.sh` | Comments updated for the no-bootloader / separate-home model. |
| `desktop/sync-limine.sh` | **New.** Copies `/nix/var/nix/profiles/system/{kernel,initrd}` to `/boot/nixos/` after a kernel change. |
| `docs/install-doom-fatal.md` | **New.** Exact install guide for this machine. |
| `docs/getting_started.md`, `desktop/README.md`, `desktop/CONTEXT.md`, `README.md`, `CLAUDE.md` | Updated to match the trial layout. |

Validation performed:

- `nix eval .#nixosConfigurations.NixIsland...` — succeeds.
- `nix eval .#nixosConfigurations.vm...` — succeeds.
- `alejandra` run on all changed `.nix` files.
- `git diff --check` clean.

The changes are **uncommitted** (`git status` shows modified files plus the two
new untracked files). The copy under `/home/moeikrey/nixos` inside the new home
is the same dirty tree, including `.git` (remote `NoahIles/dev`).

---

## 5. Install execution record

Ran as root via `pkexec` (KDE polkit agent at
`/usr/lib/polkit-kde-authentication-agent-1`; `pkexec true` returned 0).

Scripts (ephemeral, under `/tmp/opencode/`):

- `install-doom-fatal.sh` — mounts target, copies checkout, runs `nixos-install`.
- `finish-doom-fatal.sh` — stages kernel/initrd, edits `limine.conf`, unmounts.

Logs:

- `/tmp/opencode/install-doom-fatal.log`
- `/tmp/opencode/finish-doom-fatal.log`

Main install command:

```bash
nix shell nixpkgs#nixos-install-tools -c \
  nixos-install --root /mnt/nixos \
  --flake /mnt/nixos/home/moeikrey/nixos/desktop#NixIsland \
  --no-root-passwd --no-bootloader
```

`NIX_CONFIG` added the noctalia cachix substituter, which was used.

Result: **`installation finished!`**

Installed system:

```
/nix/store/fq6yy9b3cgsvbn7q73b5r704c9w7kzbq-nixos-system-DOOM-FATAL-26.05.20261021.da6dc0e
```

Kernel / initrd in the target store:

```
/nix/store/wjng0666yjjchqkf4dhhksaahhmr0dzz-linux-7.3/bzImage
/nix/store/zrki42ws8cmppkm6lq50s4nwffrs323w-initrd-linux-7.3/initrd
```

The first script exited non-zero **after** the install, because its post-check
looked for `kernel` through the absolute profile symlink. The second script then
hit `-e` on the same symlink. Both were check bugs, not install failures; see
§8.

---

## 6. Boot setup (manual Limine entry)

- `/boot/nixos/kernel` — 14 MB
- `/boot/nixos/initrd` — 27 MB
- `/boot/limine.conf` — `/NixOS` block appended at line 90
- Backup: `/boot/limine.conf.bak-<timestamp>`

Entry as installed:

```
/NixOS
    protocol: linux
    path: boot():/nixos/kernel
    module_path: boot():/nixos/initrd
    cmdline: rw root=UUID=b8f256a6-61d1-40e6-8cae-bd3b4c063caa rootfstype=btrfs rootflags=subvol=@nixos init=/nix/var/nix/profiles/system/init
```

Existing Limine settings were left alone:

```
timeout: 5
default_entry: 2
remember_last_entry: yes
```

So **CachyOS remains the default**, and the EFI boot order was not touched.
Secure Boot is off, so the kernel/initrd copies are unsigned.

---

## 7. Current state / verification

- `/mnt/nixos` is unmounted; all three mounts were cleaned up.
- `@nixos` contains `boot`, `etc`, `home`, `nix`.
- `@nixos-home/moeikrey/nixos` contains the copied checkout (2.3 MB).
- `/boot/nixos/{kernel,initrd}` exist and match the target store files
  (`cmp` passed).
- `/boot/limine.conf` contains exactly one `/NixOS` entry.
- Disk after install: **42 GB used of 55 GB, ~12 GB free** (was ~51 GB free).
  The closure is large: Steam, osu!, Zed, several Electron apps.
- **Not rebooted.**

---

## 8. Gotchas / lessons

1. **Profile symlink is absolute.** `nix/var/nix/profiles/system-1-link` points
   at `/nix/store/...`. From the live CachyOS system that resolves to the
   *host* store, not the target. Resolve it inside the target:
   `readlink /mnt/nixos/nix/var/nix/profiles/system-1-link`, then prefix with
   `/mnt/nixos`.
2. **Use `-L`, not `-e`**, when testing that symlink: `-e` follows it into the
   host store and reports missing.
3. **`nixos-generate-config` needs root** to read btrfs subvolume info.
4. **`pkexec` resets `PATH`.** Export
   `/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:...`
   explicitly.
5. **Each `pkexec` call prompts** through the KDE agent.
6. **Disk headroom is tight.** ~12 GB free. Do not put large files in the new
   home; consider trimming unused modules.

---

## 9. What remains

1. Reboot and pick **/NixOS** in Limine.
2. Log in as `moeikrey` / `moeikrey` (`initialPassword` in
   `desktop/modules/identity.nix`), then immediately run:
   ```bash
   passwd
   ```
3. Verify GPU, Wi-Fi, Bluetooth, audio, and the greetd/noctalia session.
4. Set a real git email (currently `moeikrey@localhost`).
5. Commit the config changes (they are still uncommitted in both `/nix/dev` and
   the copy in the new home).
6. Decide whether to keep `gaming.nix`, `wootility.nix`, `kokoro-tts.nix` — the
   machine has no Wooting keyboard or RodeCaster, so those are dead weight and
   disk.
7. After any kernel change inside NixOS, run `~/nixos/desktop/sync-limine.sh`
   to refresh `/boot/nixos/{kernel,initrd}`.

---

## 10. Maintenance inside NixOS

```bash
cd ~/nixos/desktop
./rebuild.sh          # builds, switches, commits
./sync-limine.sh      # only needed after a kernel change
```

`rebuild.sh` assumes a git checkout at `~/nixos`; that is why the repo was
copied into the new home during install.

---

## 11. Rollback / removing the trial

Boot back into CachyOS first (you cannot delete the running root), then:

```bash
sudo mount -o subvolid=5 \
  /dev/disk/by-uuid/b8f256a6-61d1-40e6-8cae-bd3b4c063caa /mnt
sudo btrfs subvolume delete /mnt/@nixos /mnt/@nixos-home
```

Then delete `/boot/nixos` and the `/NixOS` block from `/boot/limine.conf`.
CachyOS and its boot entry are unaffected either way.

---

## 12. Reference

- Install guide: [`install-doom-fatal.md`](install-doom-fatal.md)
- Config: `desktop/` (flake attribute `NixIsland`)
- Target mounts: `desktop/modules/hardware.nix`
- No-bootloader policy: `desktop/modules/boot.nix`
- ESP refresh: `desktop/sync-limine.sh`
