{ lib, ... }:

let 
  primaryColor = "#ffa200";
  backgroundColor = "#000000";

  fontSizes = {
    tiny   = 8;
    small  = 9;
    normal = 10;
    big    = 12;
    huge   = 16;
  };
in {
  colors = {
    primary = primaryColor;
    background = backgroundColor;

    notifications = {
      backgroundColor = backgroundColor;

      low = "#333333";
      lowText = "#aaaaaa";

      normal = primaryColor;
      normalText = "#ffffff";

      urgent = "#ff0000";
      urgentText = "#ffffff";
    };
  };

  fonts = {
    ui   = lib.mapAttrs (_: sz: "monospace ${toString sz}") fontSizes;
    mono = lib.mapAttrs (_: sz: "monospace ${toString sz}") fontSizes;
  };
}

