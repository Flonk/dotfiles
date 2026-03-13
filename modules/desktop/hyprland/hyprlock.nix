{
  pkgs,
  config,
  lib,
  ...
}:
let
  borderColor = config.skynet.theme.color.wm800.hexRgba;
  textColor = config.skynet.theme.color.text.hexRgba;
in
{
  config = lib.mkIf config.skynet.module.desktop.hyprland.enable {
    programs.hyprlock = {
      enable = true;
      settings = {
        auth = lib.mkMerge [
          {
            "pam:enabled" = true;
          }
          (lib.mkIf config.skynet.module.os.fingerprint.enable {
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
          path = builtins.toString config.skynet.theme.lockscreenImage;

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
          font_family = config.skynet.theme.fontFamily.ui;
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
          font_family = config.skynet.theme.fontFamily.ui;
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
