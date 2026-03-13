{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.skynet.module.desktop.hyprland.enable && config.skynet.wallpaper != null) (
    let
      path = builtins.toString config.skynet.wallpaper;
    in
    {
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
    }
  );
}
