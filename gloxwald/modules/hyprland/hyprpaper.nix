{
  config,
  lib,
  ...
}:
{
  options.programs.gloxwald.wallpaper = lib.mkOption {
    type = lib.types.nullOr (lib.types.either lib.types.path lib.types.package);
    default = null;
    description = "Wallpaper image; served by stylix when enabled, otherwise via hyprpaper";
  };

  config =
    lib.mkIf
      (
        config.programs.gloxwald.hyprland.enable
        && config.programs.gloxwald.wallpaper != null
        && !config.programs.gloxwald.stylix.enable
      )
      (
        let
          path = toString config.programs.gloxwald.wallpaper;
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
