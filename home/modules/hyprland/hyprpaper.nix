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

  services.hyprpaper = {
    enable = true;
    settings = {
      preload = [ path ];
      wallpaper = [
        ",${path}"
      ];
    };
  };

}
