{
  identity,
  pkgs,
  ...
}: {
  # This is the only system user managed by this host configuration.
  users.users.${identity.username} = {
    isNormalUser = true;
    uid = 1000; # matches the CachyOS user
    extraGroups = ["wheel" "networkmanager" "video" "gamemode"];
    shell = pkgs.fish;
    # Only applies when the user is first created; change it with `passwd`.
    initialPassword = identity.username;
  };

  security.sudo.extraRules = [
    {
      users = [identity.username];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];
}
