{
  pkgs,
  config,
  lib,
  ...
}:
{
  config =
    lib.mkIf
      (
        config.skynet.module.desktop.hyprland.enable
        && config.skynet.theme.wallpaper != null
        && !config.skynet.module.desktop.stylix.enable
      )
      (
        let
          path = builtins.toString config.skynet.theme.wallpaper;
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
