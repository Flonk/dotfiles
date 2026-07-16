{
  description = "GLOXWALD desktop (hyprland + quickshell bar/lockscreen + greetd greeter)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vicinae = {
      url = "github:vicinaehq/vicinae";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, stylix, vicinae }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs systems;
      pkgsFor = system: import nixpkgs { inherit system; };
    in
    {
      packages = forAllSystems (
        system:
        import ./packages.nix {
          pkgs = pkgsFor system;
          rev = self.rev or self.dirtyRev or "dev";
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/gloxwald";
        };
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              go_1_25
              grub2
              imagemagick
              just
              mtools
              OVMF.fd
              python3
              qemu
              quickshell
              qt6.qtshadertools
              watchexec
              xorriso
            ];
          };
        }
      );

      nixosModules.default = ./modules/nixos.nix;

      homeManagerModules = {
        # Batteries included: bundles the stylix and vicinae home-manager
        # modules gloxwald depends on.
        default = {
          imports = [
            stylix.homeModules.stylix
            vicinae.homeManagerModules.default
            ./modules/home-manager.nix
          ];
        };

        # Bare module for consumers that pin stylix/vicinae themselves.
        gloxwald = ./modules/home-manager.nix;
      };

      homeModules = self.homeManagerModules;
    };
}
