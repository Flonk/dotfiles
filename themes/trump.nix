{ lib, pkgs, ... }:

let
  textColor = "#ffffff";
  backgroundColor = "#000000";
  # accentColor = "#ffa200";
  accentColor = "#0090b1";

  fontSize = {
    tiny = 7.5;
    small = 8;
    normal = 9;
    big = 10.5;
    bigger = 12.5;
    huge = 14;
    humongous = 20;
  };

  fontFamily = {
    ui = "DejaVu Sans Mono";
    mono = "DejaVu Sans Mono";
  };

  lockscreenImage = ../assets/logos/andamp.png;
  # wallpaper = ../assets/wallpapers/aishot-1910.jpg;

  wallpaper =
    pkgs.runCommand "../assets/wallpapers/company_wallpaper.png"
      {
        buildInputs = [ pkgs.imagemagick ];
      }
      ''
        convert -size 3440x1440 canvas:"${accentColor}" \
          \( ${lockscreenImage} -channel rgba -fill black -colorize 100% -resize 150x150 \) \
          -gravity center -compose over -composite \
        $out
      '';
in
{
  color = {

    text = textColor;
    background = backgroundColor;
    accent = accentColor;

    notifications = {
      backgroundColor = backgroundColor;

      low = "#333333";
      lowText = "#aaaaaa";

      normal = accentColor;
      normalText = textColor;

      urgent = "#ff0000";
      urgentText = textColor;
    };
  };

  fontFamily = fontFamily;
  fontSize = fontSize;

  font = lib.mapAttrs (
    famName: famVal: lib.mapAttrs (sizeName: sz: "${famVal} ${toString sz}") fontSize
  ) fontFamily;

  wallpaper = wallpaper;
  lockscreenImage = lockscreenImage;
}
