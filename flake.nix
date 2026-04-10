{
  description = "My system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-colorizer.url = "github:nutsalhan87/nix-colorizer";

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

  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      nix-colorizer,
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
    in
    {

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;

      nixosConfigurations = {
        schnitzelwirt = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs nix-colorizer;
          };
          modules = [
            inputs.sops-nix.nixosModules.sops
            inputs.stylix.nixosModules.stylix
            ./config/hosts/schnitzelwirt
          ];
        };
        hetzy = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs nix-colorizer;
          };
          modules = [
            inputs.sops-nix.nixosModules.sops
            ./config/hosts/hetzy
          ];
        };
        bricky = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs nix-colorizer;
          };
          modules = [
            inputs.sops-nix.nixosModules.sops
            inputs.nixos-wsl.nixosModules.default
            ./config/hosts/bricky
          ];
        };
      };

      homeConfigurations = {
        flo-schnitzelwirt = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsX86;
          extraSpecialArgs = {
            inherit inputs;
            inherit nix-colorizer;
          };
          modules = [
            inputs.sops-nix.homeManagerModules.sops
            inputs.vicinae.homeManagerModules.default
            inputs.stylix.homeModules.stylix
            ./config/flo-schnitzelwirt.nix
          ];
        };
        zeroclaw-hetzy = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsAarch64;
          extraSpecialArgs = {
            inherit inputs;
            inherit nix-colorizer;
          };
          modules = [
            inputs.sops-nix.homeManagerModules.sops
            inputs.vicinae.homeManagerModules.default
            inputs.stylix.homeModules.stylix
            ./config/zeroclaw-hetzy.nix
          ];
        };
        bricky-bricky = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsX86;
          extraSpecialArgs = {
            inherit inputs;
            inherit nix-colorizer;
          };
          modules = [
            inputs.sops-nix.homeManagerModules.sops
            inputs.vicinae.homeManagerModules.default
            inputs.stylix.homeModules.stylix
            ./config/bricky-bricky.nix
          ];
        };
      };
    };

}
