{
  pkgs,
  config,
  lib,
  ...
}:
with lib;
{
  config = lib.mkIf config.skynet.module.desktop.waybar.enable {
    # Configure & Theme Waybar
    programs.waybar = {
      enable = true;
      package = pkgs.waybar;
      settings = [
        {
          layer = "bottom";
          position = "bottom";

          modules-center = [
          ];
          modules-left = [
            "hyprland/workspaces"
            "hyprland/window"
          ];

          modules-right = [
            "pulseaudio"
            "battery"
            "custom/label-bat"
            "tray"
            "clock"
          ];

          "hyprland/workspaces" = {
            format = "{name}";
            format-icons = {
              default = " ";
              active = " ";
              urgent = " ";
            };
            on-scroll-up = "hyprctl dispatch workspace e+1";
            on-scroll-down = "hyprctl dispatch workspace e-1";
          };

          "clock" = {
            interval = 1;
            format = "{:%Y-%m-%d %H:%M:%S}";
          };

          "hyprland/window" = {
            max-length = 40;
            separate-outputs = false;
          };

          "tray" = {
            spacing = 12;
          };

          "pulseaudio" = {
            format = "{volume}%";
            on-click = "pavucontrol";
          };

          "custom/label-bat" = {
            format = "BAT";
            tooltip = false;
          };

          "battery" = {
            states = {
              warning = 30;
              critical = 15;
            };
            format = "{capacity}%";
            format-charging = "+{capacity}%";
            format-plugged = "+{capacity}%";
          };
        }
      ];
      style = concatStrings [
        ''
          * {
            font-size: 10px;
            margin: 0 5px;
            padding: 0;
            font-family: monospace;
          }

          window#waybar {
            border-radius: 0px;
          }

          #workspaces {
            border: 0px;
            font-style: normal;
            margin: 2px;
          }

          #workspaces button {
            border-radius: 0;
          }

          #workspaces button:hover {
            border: 0px solid transparent;
          }

          tooltip {
            border-radius: 10px;
          }

          tooltip label {
          }

          #cpu, #memory, #battery {
            margin: 0;
            padding: 0;
          }

          #custom-label-cpu, #custom-label-mem, #custom-label-bat {
            margin-right: 12px;
          }
        ''
      ];
    };

    systemd.user.services.waybar = {
      Unit = {
        Description = "Waybar panel";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        EnvironmentFile = "-%t/quickshell.env";
        ExecStart = "${pkgs.waybar}/bin/waybar";
        Restart = "on-failure";
        RestartSec = 1;
      };
      # No Install section -> not started automatically; managed by powersaver.
    };
  };
}
