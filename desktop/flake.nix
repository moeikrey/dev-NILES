{
  description = "Noah's NixOS config — niri + noctalia";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # No nixpkgs.follows on either: noctalia.cachix.org only holds builds made
    # against upstream's own locked nixpkgs (see configuration.nix). The
    # cachix branch only advances once upstream CI has pushed that build.
    noctalia.url = "github:noctalia-dev/noctalia-shell/cachix";
    noctalia-greeter.url = "github:noctalia-dev/noctalia-greeter";
    # Same cache rule as noctalia: the cachix branch only advances once
    # umbriel.cachix.org has the build.
    umbriel.url = "github:noctalia-dev/umbriel/cachix";

    # screenshot annotator / lightweight image editor; not in nixpkgs
    swash = {
      url = "github:ItsLemmy/swash";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      # ponytail: needs ffmpeg_9, not in nixos-26.05
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    helium-browser = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Apple SF fonts ("SF Hello" = SF Pro). Not in nixpkgs — proprietary.
    apple-fonts = {
      url = "github:Lyndeno/apple-fonts.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # borghei/ink has no flake of its own — this is our packaging fork
    # (NoahIles/ink), synced from upstream monthly by its own CI.
    ink.url = "github:NoahIles/ink";

    # wooting-bg-service isn't in nixpkgs yet — tracking the open,
    # unmerged nixpkgs PR (NixOS/nixpkgs#529138) as a temporary input.
    # Delete this input once that PR merges and switch back to nixpkgs.
    wooting-nixpkgs.url = "github:hustlerone/nixpkgs-kmscon-no-drm/wooting";

    # Claude Desktop isn't in nixpkgs — Anthropic ships the Linux beta as a
    # .deb only. This community flake repackages that official .deb.
    claude-desktop = {
      url = "github:aaddrick/claude-desktop-debian";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
    identity = import ./identity.nix;
    pkgs-unstable = import inputs.nixpkgs-unstable {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
    ink-md = inputs.ink.packages.x86_64-linux.default;
    pkgs-wooting = import inputs.wooting-nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
    sharedModules = [
      ./configuration.nix
      ./modules/desktop.nix
      # Compositors: drop either import to stop building/offering that session.
      ./modules/niri.nix
      ./modules/umbriel.nix
      ./modules/apps.nix
      ./modules/cli.nix
      ./modules/performance.nix
      ./modules/fonts.nix
      ./modules/identity.nix
      home-manager.nixosModules.home-manager
      inputs.noctalia-greeter.nixosModules.default
      {
        # Ties each generation back to the commit it was built from; shows up
        # in `nixos-rebuild list-generations`. See docs/adr/0001.
        system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or "dirty";

        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        # Live-lane dotfiles are symlinks back into this repo; if something
        # replaces one with a real file, activation would abort. Back it up
        # and carry on instead of forcing (force silently eats hand-edits
        # that never made it to git).
        home-manager.backupFileExtension = "hm-bak";
        home-manager.extraSpecialArgs = {
          inherit identity inputs pkgs-unstable;
        };
        home-manager.users.${identity.username} = import ./home.nix;
      }
    ];
  in {
    # DESKTOP
    nixosConfigurations.NixIsland = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit identity inputs pkgs-unstable ink-md pkgs-wooting;};
      modules =
        sharedModules
        ++ [
          ./modules/boot.nix
          ./modules/gaming.nix
          ./modules/kokoro-tts.nix
          ./modules/wootility.nix
          ./modules/hardware.nix
          # Per-host, not in sharedModules: vm.nix sets it true, and two
          # definitions of the same key in this attrs option can't override.
          {home-manager.extraSpecialArgs._isVM = false;}
        ];
    };
    # VM
    nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit identity inputs pkgs-unstable ink-md;};
      modules = sharedModules ++ [./vm.nix];
    };
  };
}
