{
  description = "My system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gauntlet = {
      url = "github:project-gauntlet/gauntlet";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    walker.url = "github:abenz1267/walker";

    nix-colorizer.url = "github:nutsalhan87/nix-colorizer";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      nix-colorizer,
      ...
    }:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;

      nixosConfigurations = {
        schnitzelwirt = nixpkgs.lib.nixosSystem {
          modules = [
            ./hosts/schnitzelwirt.nix
          ];
        };
      };

      homeConfigurations = {
        flo = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit inputs;
            inherit nix-colorizer;
            theme = import ./themes/trump.nix {
              lib = pkgs.lib;
              pkgs = pkgs;
              nix-colorizer = inputs.nix-colorizer;
            };
          };
          modules = [
            ./home/flo.nix
          ];
        };
      };
    };

}
