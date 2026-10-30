{
  identity,
  inputs,
  ...
}: {
  imports = [
    ./modules/home/programs.nix
    ./modules/home/dotfiles.nix
    ./modules/home/claude.nix
    inputs.noctalia.homeModules.default
  ];

  home.username = identity.username;
  home.homeDirectory = identity.homeDirectory;
  home.stateVersion = "26.05";

  # ponytail: the NixOS home is its own @nixos-home subvolume, but most of
  # ~/.config still stays canonical/loose (niri, noctalia, fish, …) via the
  # live-lane symlinks in modules/home/dotfiles.nix; migration to HM-managed
  # files is piecemeal.

  # Runs noctalia as a user unit (Restart=on-failure, own journal) instead of
  # niri's spawn-at-startup. `settings`/`customPalettes` stay unset on purpose:
  # setting either makes the module declare xdg.configFile."noctalia/config.toml",
  # which collides with the whole-directory live-lane symlink in dotfiles.nix.
  # Real user config lives in ~/.local/state/noctalia/settings.toml, which the
  # module never touches.
  programs.noctalia = {
    enable = true;
    systemd.enable = true;
  };
  # Apps opened from the launcher land in this unit's cgroup; some (jellyfin-
  # desktop) ignore SIGTERM and stalled every reboot for the 90s default.
  systemd.user.services.noctalia.Service.TimeoutStopSec = "5s";

  # ShadowPlay-style replay buffer. The F24 bind in configs/niri/keybinds.kdl
  # flushes it with SIGUSR1; -sc runs gsr-save-hook on the saved file.
  # ponytail: hardcoded to DP-1 (the ultrawide) — swap to -w DP-2 or add a
  # second unit if the other monitor ever needs it.
  systemd.user.services.gpu-screen-recorder = {
    Unit = {
      Description = "gpu-screen-recorder replay buffer";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "/run/current-system/sw/bin/gpu-screen-recorder -w DP-1 -f 60 -r 60 -c mp4 -a default_output -replay-storage ram -o %h/Videos/clips -sc %h/.config/niri/scripts/gsr-save-hook";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = ["graphical-session.target"];
  };
}
