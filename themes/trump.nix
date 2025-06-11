{ lib, ... }:

let 
  textColor = "#ffffff";
  backgroundColor = "#000000";
  accentColor = "#ffa200";

  fontSize = {
    tiny   = 7.5;
    small  = 8;
    normal = 9;
    big    = 10.5;
    huge   = 14;
  };

  wallpaper = ../assets/wallpapers/aishot-1910.jpg;
in {
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

  fonts = {
    ui   = lib.mapAttrs (_: sz: "monospace ${toString sz}") fontSize;
    mono = lib.mapAttrs (_: sz: "monospace ${toString sz}") fontSize;
  };

  fontSize = fontSize;
  wallpaper = wallpaper;
}

