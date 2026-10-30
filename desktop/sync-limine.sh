#!/usr/bin/env bash
# Copy the current system's kernel + initrd to the shared ESP so the manual
# Limine entry keeps booting after a rebuild. Run after `nixos-rebuild switch`
# (or ./rebuild.sh), and always after a kernel change.
set -euo pipefail

esp="${ESP:-/boot}"
src=/nix/var/nix/profiles/system

sudo mkdir -p "$esp/nixos"
sudo cp -L "$src/kernel" "$esp/nixos/kernel"
sudo cp -L "$src/initrd" "$esp/nixos/initrd"
echo "synced $esp/nixos/{kernel,initrd}"
