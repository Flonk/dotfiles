{
  description = "My system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, ... }:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {

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
            theme = import ./themes/trump.nix { lib = pkgs.lib; };
          };
          modules = [
            ./home/flo.nix
          ];
        };
      };
    };
  
}
