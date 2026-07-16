{ lib, ... }:
{
  imports = [
    ./hyprland.nix
    ./hyprcursor.nix
    ./hyprpaper.nix
    ./hyprpicker.nix
    ./i18n.nix
    ./mako.nix
    ./style.nix
    ./vicinae.nix
  ];

  options.programs.gloxwald.hyprland.enable =
    lib.mkEnableOption "gloxwald hyprland session";
}
