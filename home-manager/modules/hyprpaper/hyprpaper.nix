{
  pkgs,
  config,
  lib,
  ...
}: {
  
  programs.hyprpaper = {
    enable = true;
    settings = {
      preload = [ "../../../assets/wallpapers/aishot-1910.jpg" ];
      wallpaper = [
        ",../../../assets/wallpapers/aishot-1910.jpg"
      ];
    };
  };
  
}
