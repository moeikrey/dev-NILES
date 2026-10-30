{config, ...}: {
  # Hardware for DOOM-FATAL: ASUS TUF GAMING B650E-E WIFI, AMD Ryzen 7
  # 9800X3D, NVIDIA RTX 3060 Ti (GA104) + Radeon 610M iGPU.
  #
  # Storage: NixOS is a trial install alongside CachyOS, entirely on the
  # 55 GB "NIX" btrfs (sdb4). @nixos is /, @nixos-home is /home, and the
  # Nix store lives inside @nixos. CachyOS keeps its own store on the
  # top-level subvolume it mounts at /nix; that mount is deliberately not
  # reused here.
  #
  # The ESP is nvme0n1p5, shared with CachyOS's Limine. NixOS installs no
  # bootloader (see modules/boot.nix); /boot is mounted only to stage the
  # manual Limine entry.
  boot.initrd.availableKernelModules = [
    "btrfs"
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
    "uas"
  ];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd"];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/b8f256a6-61d1-40e6-8cae-bd3b4c063caa";
    fsType = "btrfs";
    options = ["subvol=@nixos" "noatime" "compress=zstd:3" "discard=async" "commit=120"];
  };
  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/b8f256a6-61d1-40e6-8cae-bd3b4c063caa";
    fsType = "btrfs";
    options = ["subvol=@nixos-home" "noatime" "compress=zstd:3" "discard=async" "commit=120"];
  };
  # Shared ESP: CachyOS's Limine lives here. Mount it, but do not let NixOS
  # own it (boot.nix disables every bootloader).
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/E452-3E68";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };

  swapDevices = []; # zramSwap is enabled in modules/boot.nix

  nixpkgs.hostPlatform = "x86_64-linux";
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;

  # RTX 3060 Ti (Ampere): the open kernel modules are supported.
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    powerManagement.enable = true;
  };
  # If the monitor is plugged into the motherboard (Radeon 610M) instead of
  # the 3060 Ti, enable PRIME offload:
  # hardware.nvidia.prime = {
  #   offload.enable = true;
  #   nvidiaBusId = "PCI:1:0:0";
  #   amdgpuBusId = "PCI:12:0:0";
  # };

  # MediaTek MT7922 (Wi-Fi + Bluetooth); firmware comes from
  # enableRedistributableFirmware above.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
}
