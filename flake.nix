{
  description = "My system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gauntlet = {
      url = github:project-gauntlet/gauntlet;
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, inputs, ... }:
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
            self = self;
            theme = import ./themes/trump.nix { lib = pkgs.lib; };
            inputs = inputs;
          };
          modules = [
            ./home/flo.nix
          ];
        };
      };
    };
  
}
