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

    skynetshell = {
      url = "path:/home/flo/repos/personal/skynetshell";
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
    in
    {

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;

      nixosConfigurations = {
        schnitzelwirt = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
          };
          modules = [
            inputs.sops-nix.nixosModules.sops
            inputs.stylix.nixosModules.stylix
            ./config/hosts/schnitzelwirt
          ];
        };
        chonkler = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
          };
          modules = [
            inputs.sops-nix.nixosModules.sops
            inputs.stylix.nixosModules.stylix
            inputs.skynetshell.nixosModules.default
            ./config/hosts/chonkler
          ];
        };
        bricky = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
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
          };
          modules = [
            inputs.sops-nix.homeManagerModules.sops
            inputs.vicinae.homeManagerModules.default
            inputs.stylix.homeModules.stylix
            ./config/flo-schnitzelwirt.nix
          ];
        };
        flo-chonkler = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsX86;
          extraSpecialArgs = {
            inherit inputs;
          };
          modules = [
            inputs.sops-nix.homeManagerModules.sops
            inputs.vicinae.homeManagerModules.default
            inputs.stylix.homeModules.stylix
            inputs.skynetshell.homeManagerModules.default
            ./config/flo-chonkler.nix
          ];
        };
        bricky-bricky = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsX86;
          extraSpecialArgs = {
            inherit inputs;
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
