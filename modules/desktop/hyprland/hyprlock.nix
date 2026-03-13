{
  pkgs,
  config,
  lib,
  ...
}:
let
  stripHash = hex: lib.replaceStrings [ "#" ] [ "" ] hex;
  toRgba = hex: "rgba(${stripHash hex}ff)";

  borderColor = toRgba config.theme.color.wm800;
  textColor = toRgba config.theme.color.text;
in
{
  config = lib.mkIf config.skynet.module.hyprland.enable {
    programs.hyprlock = {
      enable = true;
      settings = {
        auth = lib.mkMerge [
          {
            "pam:enabled" = true;
          }
          (lib.mkIf config.skynet.module.fingerprint.enable {
            "fingerprint:enabled" = true;
            "fingerprint:ready_message" = "(Scan fingerprint to unlock)";
            "fingerprint:present_message" = "Scanning fingerprint";
          })
        ];

        background = {
          path = "screenshot";

          blur_passes = 2;
          blur_size = 7;
          noise = 1.2e-2;
          contrast = 0.6;
          brightness = 0.6;
        };

        image = {
          path = builtins.toString config.theme.lockscreenImage;

          position = "0, 0";
          halign = "center";
          valign = "center";
          border_size = 0;
          rounding = 0;
          size = 150;
        };

        label = {
          text = "";
          color = textColor;
          font_size = 80;
          font_family = config.theme.fontFamily.ui;
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
          font_family = config.theme.fontFamily.ui;
          fade_on_empty = false;
          placeholder_text = "";
          fail_text = "❌";
          size = "320, 320";
          zindex = 100;
        };
      };
    };
  };
}
