{
  identity,
  inputs,
  ...
}: {
  networking.hostName = identity.hostName;
  networking.networkmanager.enable = true;

  time.timeZone = "America/Los_Angeles";

  nix.settings.experimental-features = ["nix-command" "flakes"];
  # noctalia + noctalia-greeter are compiled C++; upstream CI publishes them
  # here, built against the nixpkgs in upstream's own flake.lock. So their
  # inputs must not follow our nixpkgs (flake.nix). If they start compiling
  # again, check `nix flake metadata` shows their nixpkgs as upstream's pin;
  # removing a follows needs `nix flake update noctalia noctalia-greeter`
  # before the lock picks that pin up.
  nix.settings = {
    extra-substituters = ["https://noctalia.cachix.org"];
    extra-trusted-public-keys = ["noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="];
  };
  nix.registry = {
    stable.flake = inputs.nixpkgs;
    unstable.flake = inputs.nixpkgs-unstable;
  };
  nixpkgs.config.allowUnfree = true; # nvidia, steam, zed extensions etc.
  # flakes (nix shell/run/build) ignore nixpkgs.config; this covers those

  programs.fish.enable = true;

  # the home subvolume has AppImages (~/.local/bin) and CachyOS-built binaries
  programs.appimage = {
    enable = true;
    binfmt = true;
  };
  programs.nix-ld.enable = true;

  # ShadowPlay-style replay buffer; module handles the setcap wrapper
  programs.gpu-screen-recorder.enable = true;

  system.stateVersion = "26.05";
}
