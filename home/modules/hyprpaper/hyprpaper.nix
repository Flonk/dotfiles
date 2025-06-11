{
  pkgs,
  config,
  lib,
  ...
}: let
  wallpaper = "${config.home.homeDirectory}/.config/wallpapers/aishot-1910.jpg";
in {
  
  services.hyprpaper = {
    enable = true;
    settings = {
      preload = [ wallpaper ];
      wallpaper = [
        ",${wallpaper}"
      ];
    };
  };
  
}
