{
  pkgs,
  config,
  lib,
  ...
}:
{
  options.programs.gloxwald.hyprland.enable =
    lib.mkEnableOption "gloxwald hyprland session";

  config = lib.mkIf config.programs.gloxwald.hyprland.enable {
    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-hyprland
        pkgs.xdg-desktop-portal-gtk
      ];
      config.common.default = [
        "hyprland"
        "gtk"
      ];
    };
  };
}
