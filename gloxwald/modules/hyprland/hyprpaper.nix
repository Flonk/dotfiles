{
  config,
  lib,
  ...
}:
{
  config =
    lib.mkIf
      (
        config.programs.gloxwald.hyprland.enable
        && config.skynet.module.desktop.stylix.wallpaper != null
        && !config.skynet.module.desktop.stylix.enable
      )
      (
        let
          path = toString config.skynet.module.desktop.stylix.wallpaper;
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
