{
  pkgs,
  config,
  lib,
  theme,
  ...
}: let
  stripHash = hex: lib.replaceStrings [ "#" ] [ "" ] hex;
  toRgba    = hex: "rgba(${ stripHash hex }ff)";

  borderColor = toRgba theme.color.accent;
  textColor = toRgba theme.color.text;
in {
  
  programs.hyprlock = {
    enable = true;
    settings = {
      background = {
        path = "screenshot";

        blur_passes = 2; 
        blur_size = 7;
        noise = 1.2e-2;
        contrast = 0.6;
        brightness = 0.6;
      };

      image = {
        path = builtins.toString theme.lockscreenImage;

        position = "0, 50";
        halign = "center";
        valign = "center";
        border_size = 0;
        rounding = 0;
      };

      label = {
        text = "$TIME";
        color = textColor;
        font_size = theme.fontSize.humongous;
        font_family = theme.fontFamily.ui;
        position = "0, 200";
        halign = "center";
        valign = "center";
      };


      input-field = {
        outer_color = borderColor;
      };
    };
  };
  
}
