{
  pkgs,
  config,
  lib,
  theme,
  ...
}:
let
  stripHash = hex: lib.replaceStrings [ "#" ] [ "" ] hex;
  toRgba = hex: "rgba(${stripHash hex}ff)";

  borderColor = toRgba theme.color.wm800;
  textColor = toRgba theme.color.text;
in
{

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

        position = "0, -20";
        halign = "center";
        valign = "top";
        border_size = 0;
        rounding = 0;
        size = 20;
      };

      label = {
        text = "🥸";
        color = textColor;
        font_size = 80;
        font_family = theme.fontFamily.ui;
        position = "0, 0";
        halign = "center";
        valign = "center";
      };

      input-field = {
        hide_input = true;
        outer_color = "rgba(ffffff00)";
        inner_color = "rgba(ffffff00)";
        outline_thickness = 30;
        font_size = 20;
        font_family = theme.fontFamily.ui;
        fade_on_empty = false;
        placeholder_text = "🥸";
        fail_text = "❌";
        size = "320, 320";
        zindex = 100;
      };
    };
  };

}
