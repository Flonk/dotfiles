{
  description = "My system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
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
            theme = import ./themes/trump.nix {
              lib = pkgs.lib;
              pkgs = pkgs;
            };
          };
          modules = [
            ./home/flo.nix
          ];
        };
      };
    };

}
