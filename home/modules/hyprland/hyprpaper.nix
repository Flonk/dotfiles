{
  pkgs,
  config,
  lib,
  theme,
  ...
}: let 
  path = builtins.toString theme.wallpaper;
in {
  
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
