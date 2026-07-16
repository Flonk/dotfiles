{ lib, ... }:
{
  imports = [
    ./hyprland.nix
    ./hyprlock.nix
    ./hyprcursor.nix
    ./hyprpaper.nix
    ./hyprpicker.nix
    ./style.nix
  ];

  options.programs.gloxwald.hyprland.enable =
    lib.mkEnableOption "gloxwald hyprland session";
}
