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

    vicinae = {
      url = "github:vicinaehq/vicinae";
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

    mazama = {
      url = "github:Flonk/mazama";
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
            ./modules/desktop/gloxwald/system.nix
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
            inputs.mazama.homeManagerModules.default
            inputs.stylix.homeModules.stylix
            ./modules/desktop/gloxwald/home.nix
            ./config/installations/${name}.nix
          ]
          ++ extraModules;
        };
    in
    {

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;

      packages.x86_64-linux = import ./modules/desktop/gloxwald/packages.nix {
        pkgs = pkgsX86;
        rev = self.rev or self.dirtyRev or "dev";
      };

      nixosConfigurations = {
        chonkler = mkSystem "chonkler" { };
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
