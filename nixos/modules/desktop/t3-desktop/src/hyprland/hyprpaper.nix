{
  config,
  lib,
  ...
}:
{
  config =
    lib.mkIf
      (
        config.programs.t3-desktop.hyprland.enable
        && config.programs.t3-desktop.wallpaper != null
        && !config.programs.t3-desktop.stylix.enable
      )
      (
        let
          path = toString config.programs.t3-desktop.wallpaper;
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
