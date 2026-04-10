{
  pkgs,
  config,
  lib,
  ...
}:
let
  s = config.lib.stylix.colors.withHashtag;
  textColor = "rgba(${builtins.substring 1 6 s.base07}ff)";
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
          path = lib.mkForce "screenshot";

          blur_passes = 2;
          blur_size = 7;
          noise = 1.2e-2;
          contrast = 0.6;
          brightness = 0.6;
        };

        image = {
          path = builtins.toString config.skynet.module.desktop.stylix.lockscreenImage;

          position = "0, 0";
          halign = "center";
          valign = "center";
          border_size = 0;
          rounding = 0;
          size = 150;
        };

        label = {
          text = "";
          font_size = 80;
          font_family = lib.mkDefault config.stylix.fonts.sansSerif.name;
          position = "0, 0";
          halign = "center";
          valign = "center";
        };

        input-field = {
          hide_input = true;
          outer_color = lib.mkForce "rgba(ffffff00)";
          inner_color = lib.mkForce "rgba(ffffff00)";
          outline_thickness = 30;
          font_size = 20;
          font_family = lib.mkDefault config.stylix.fonts.sansSerif.name;
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
