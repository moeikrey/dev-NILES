rec {
  username = "moeikrey";
  homeDirectory = "/home/${username}";
  fullName = "Andre";
  # TODO: set the email you want git commits to use.
  email = "moeikrey@localhost";
  hostName = "DOOM-FATAL";
  # No checked-in keys; SSH is not imported by desktop/flake.nix either.
  sshKeys = [];
}
