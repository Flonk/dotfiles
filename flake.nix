{
  description = "My system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
  };

  outputs = inputs@{ self, nixpkgs, home-manager, nix-vscode-extensions, ... }:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {

      nixpkgs.overlays = [
        nix-vscode-extensions.overlays.default
      ];

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
