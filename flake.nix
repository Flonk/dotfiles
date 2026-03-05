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

    quickmilk = {
      url = "path:/home/flo/repos/personal/quickmilk";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vicinae = {
      url = "github:vicinaehq/vicinae";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vicinae-extensions = {
      url = "github:vicinaehq/extensions";
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
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          inputs.antigravity-nix.overlays.default
        ];
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
            ./config/hosts/schnitzelwirt
          ];
        };
      };

      homeConfigurations = {
        flo-schnitzelwirt = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit inputs;
            inherit nix-colorizer;
          };
          modules = [
            inputs.sops-nix.homeManagerModules.sops
            inputs.vicinae.homeManagerModules.default
            ./config/flo-schnitzelwirt.nix
          ];
        };
      };
    };

}
