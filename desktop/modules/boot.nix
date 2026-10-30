{pkgs-unstable, ...}: {
  # Trial install: CachyOS's Limine stays in charge of the ESP. NixOS installs
  # no bootloader and does not touch the EFI boot order, so the host remains
  # bootable even if this configuration is wrong.
  #
  # After `nixos-install --no-bootloader`, stage the kernel + initrd on the
  # ESP and add a Limine entry by hand:
  #
  #   sudo mkdir -p /mnt/nixos/boot/nixos
  #   sudo cp -L /mnt/nixos/nix/var/nix/profiles/system/{kernel,initrd} /mnt/nixos/boot/nixos/
  #
  # then in the host's limine.conf:
  #
  #   /NixOS
  #     protocol: linux
  #     path: boot():/nixos/kernel
  #     module_path: boot():/nixos/initrd
  #     cmdline: rw root=UUID=b8f256a6-61d1-40e6-8cae-bd3b4c063caa rootflags=subvol=@nixos init=/nix/var/nix/profiles/system/init
  #
  # Re-copy kernel/initrd after every kernel change. Once the trial becomes
  # permanent, hand the ESP to boot.loader.limine and delete this note.
  boot.loader.grub.enable = false;
  boot.loader.systemd-boot.enable = false;
  boot.loader.limine.enable = false;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.efi.efiSysMountPoint = "/boot";

  # 9800X3D + RTX 3060 Ti; no hardware here needs the testing kernel.
  boot.kernelPackages = pkgs-unstable.linuxPackages_latest;

  # all magic sysrq functions (default 16 = sync only), for REISUB
  boot.kernel.sysctl."kernel.sysrq" = 1;

  zramSwap.enable = true;
}
