{
  description = "My system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-2405.url = "github:NixOS/nixpkgs/nixos-24.05";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    openconnect-pulse-launcher = {
      url = "github:erahhal/openconnect-pulse-launcher";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vicinae = {
      url = "github:vicinaehq/vicinae";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    balaclava = {
      url = "github:Flonk/balaclava";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gloxwald = {
      url = "path:../gloxwald";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      sops-nix,
      ...
    }:
    let
      lib = nixpkgs.lib;
      pkgsX86 = import nixpkgs {
        system = "x86_64-linux";
      };
      pkgsAarch64 = import nixpkgs {
        system = "aarch64-linux";
      };

      mkSystem =
        name:
        {
          extraModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
          };
          modules = [
            inputs.sops-nix.nixosModules.sops
            inputs.stylix.nixosModules.stylix
            inputs.gloxwald.nixosModules.default
            ./config/hosts/${name}
          ]
          ++ extraModules;
        };

      mkHome =
        name:
        {
          pkgs ? pkgsX86,
          extraModules ? [ ],
        }:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit inputs;
          };
          modules = [
            inputs.sops-nix.homeManagerModules.sops
            inputs.vicinae.homeManagerModules.default
            inputs.stylix.homeModules.stylix
            inputs.gloxwald.homeManagerModules.gloxwald
            ./config/installations/${name}.nix
          ]
          ++ extraModules;
        };
    in
    {

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;

      packages.x86_64-linux = inputs.gloxwald.packages.x86_64-linux;

      nixosConfigurations = {
        schnitzelwirt = mkSystem "schnitzelwirt" { };
        chonkler = mkSystem "chonkler" { };
        bricky = mkSystem "bricky" {
          extraModules = [ inputs.nixos-wsl.nixosModules.default ];
        };
        hetzner = mkSystem "hetzner" { };
      };

      homeConfigurations =
        let
          installationFiles = builtins.attrNames (builtins.readDir ./config/installations);
          names = map (f: lib.removeSuffix ".nix" f) (
            builtins.filter (f: lib.hasSuffix ".nix" f) installationFiles
          );
        in
        lib.genAttrs names (name: mkHome name { });
    };

}
