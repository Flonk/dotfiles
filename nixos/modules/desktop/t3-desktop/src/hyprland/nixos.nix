{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.programs.t3-desktop.hyprland.enable {
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
