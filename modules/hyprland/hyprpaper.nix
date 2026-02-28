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
        preload = [ path ];
        wallpaper = [
          ",contain:${path}"
        ];
      };
    };
  };
}
