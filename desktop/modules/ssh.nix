{identity, ...}: {
  # Not imported by desktop/flake.nix. If you re-enable it, add keys to
  # identity.nix first: PasswordAuthentication is disabled below.
  services.openssh = {
    enable = true;
    ports = [2222];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  users.users.${identity.username}.openssh.authorizedKeys.keys = identity.sshKeys;
}
