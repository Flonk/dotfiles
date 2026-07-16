{
  description = "GLOXWALD desktop (hyprland + quickshell bar/lockscreen + greetd greeter)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
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
      homeManagerModules.default = ./modules/home-manager.nix;
    };
}
