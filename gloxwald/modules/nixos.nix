{ ... }:
{
  imports = [
    ./options.nix
    ../src/greeter/nixos.nix
    ../src/grub/nixos.nix
    ../src/hyprland/nixos.nix
  ];
}
