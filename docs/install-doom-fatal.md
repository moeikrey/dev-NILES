# Installing this config on DOOM-FATAL

A trial NixOS install **alongside CachyOS**, with no repartitioning and with
CachyOS's Limine left in charge of the ESP. The generic version of this guide
is [`getting_started.md`](getting_started.md); this page has the values for
this machine.

## Layout

| Mount | Device | Subvolume / fs | Notes |
|---|---|---|---|
| `/` | `/dev/sdb4` | btrfs `@nixos` | UUID `b8f256a6-61d1-40e6-8cae-bd3b4c063caa` |
| `/home` | `/dev/sdb4` | btrfs `@nixos-home` | same filesystem, separate subvolume |
| `/boot` | `/dev/nvme0n1p5` | vfat | UUID `E452-3E68`, shared with CachyOS Limine |

`@nixos` and `@nixos-home` already exist on the `NIX` drive. The Nix store
lives **inside `@nixos`**; CachyOS's top-level store (mounted at `/nix`) is not
reused.

## 1. Mount the target

```bash
sudo mkdir -p /mnt/nixos
sudo mount -o subvol=@nixos \
  /dev/disk/by-uuid/b8f256a6-61d1-40e6-8cae-bd3b4c063caa /mnt/nixos
sudo mkdir -p /mnt/nixos/{home,boot}
sudo mount -o subvol=@nixos-home \
  /dev/disk/by-uuid/b8f256a6-61d1-40e6-8cae-bd3b4c063caa /mnt/nixos/home
sudo mount /dev/disk/by-uuid/E452-3E68 /mnt/nixos/boot
```

## 2. Put the checkout in the new home

The live-lane dotfiles point at `~/nixos/desktop/configs`, so the checkout has
to exist at `/home/moeikrey/nixos` **inside the target home**:

```bash
sudo install -d -o 1000 -g 1000 /mnt/nixos/home/moeikrey
sudo install -d -o 1000 -g 1000 /mnt/nixos/home/moeikrey/nixos
sudo cp -a /nix/dev/. /mnt/nixos/home/moeikrey/nixos/
sudo chown -R 1000:1000 /mnt/nixos/home/moeikrey
```

## 3. Install

```bash
sudo env PATH="$PATH" nix --extra-experimental-features 'nix-command flakes' \
  shell nixpkgs#nixos-install-tools -c \
  nixos-install --root /mnt/nixos \
  --flake /mnt/nixos/home/moeikrey/nixos/desktop#NixIsland \
  --no-root-passwd --no-bootloader
```

`--no-bootloader` is deliberate. `modules/boot.nix` disables GRUB,
systemd-boot and Limine, and sets `canTouchEfiVariables = false`, so NixOS
never writes to the ESP or changes the EFI boot order.

The `NIX` drive has roughly 53 GB free; the NixOS store and the new home share
it. This closure is large (Steam, osu!, Zed, several Electron apps): the install
used about 39 GB, leaving roughly 12 GB free. Check `df -h /nix` before relying
on the new home for big files.

## 4. Stage the kernel and add the Limine entry

The `system` profile symlink is absolute (`/nix/store/…`), so from the live
system it points at the *host* store, not the target. Resolve it inside
`/mnt/nixos` first:

```bash
sudo mkdir -p /mnt/nixos/boot/nixos
system=$(readlink /mnt/nixos/nix/var/nix/profiles/system-1-link)
kernel=$(readlink "/mnt/nixos$system/kernel")
initrd=$(readlink "/mnt/nixos$system/initrd")
sudo cp "/mnt/nixos$kernel" /mnt/nixos/boot/nixos/kernel
sudo cp "/mnt/nixos$initrd" /mnt/nixos/boot/nixos/initrd

sudo find /mnt/nixos/boot -maxdepth 3 -name 'limine.conf'
```

Edit that file (usually `/mnt/nixos/boot/limine.conf`) and add:

```
/NixOS
    protocol: linux
    path: boot():/nixos/kernel
    module_path: boot():/nixos/initrd
    cmdline: rw root=UUID=b8f256a6-61d1-40e6-8cae-bd3b4c063caa rootfstype=btrfs rootflags=subvol=@nixos init=/nix/var/nix/profiles/system/init
```

Secure Boot is off, so the copies do not need signing.

## 5. Unmount and reboot

```bash
sudo umount /mnt/nixos/boot /mnt/nixos/home /mnt/nixos
sudo reboot
```

Pick **NixOS** in Limine. Log in as `moeikrey` with password `moeikrey`
(`initialPassword` in `modules/identity.nix`), then immediately run `passwd`.

## Rebuilds

```bash
cd ~/nixos/desktop && ./rebuild.sh
./sync-limine.sh   # after a kernel change: refreshes /boot/nixos/{kernel,initrd}
```

The manual Limine entry points at the copies on the ESP, so they must be
refreshed after a kernel bump. Once the trial becomes permanent, enable
`boot.loader.limine` and let NixOS own the ESP instead.

## Removing the trial

Boot back into CachyOS first (you cannot delete the running root), then:

```bash
sudo mount -o subvolid=5 \
  /dev/disk/by-uuid/b8f256a6-61d1-40e6-8cae-bd3b4c063caa /mnt
sudo btrfs subvolume delete /mnt/@nixos /mnt/@nixos-home
```

Then delete `/boot/nixos` and the `/NixOS` block from `limine.conf`.
