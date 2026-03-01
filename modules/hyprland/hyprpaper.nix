{
  pkgs,
  config,
  lib,
  ...
}:
let
  path = builtins.toString config.theme.wallpaper;
in
{
  config = lib.mkIf config.skynet.module.hyprland.enable {
    services.hyprpaper = {
      enable = true;
      settings = {
        splash = false;
        preload = path;
        wallpaper = {
          monitor = "";
          path = path;
          fit_mode = "cover";
        };
      };
    };
  };
}
