{
  pkgs,
  config,
  lib,
  theme,
  ...
}:
with lib;
{
  # Configure & Theme Waybar
  programs.waybar = {
    enable = true;
    package = pkgs.waybar;
    settings = [
      {
        layer = "bottom";
        position = "bottom";

        modules-center = [ ];
        modules-left = [
          "custom/startmenu"
          "hyprland/workspaces"
          "hyprland/window"
        ];
        modules-right = [
          "pulseaudio"
          "cpu"
          "memory"
          "battery"
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
          format = ''{:%Y-%m-%d %H:%M:%S}'';
        };

        "hyprland/window" = {
          max-length = 60;
          separate-outputs = false;
        };

        "memory" = {
          interval = 5;
          format = "MEM {}%";
        };

        "cpu" = {
          interval = 5;
          format = "CPU {usage:2}%";
        };

        "tray" = {
          spacing = 12;
        };

        "pulseaudio" = {
          format = "VOL {volume}%";
          on-click = "pavucontrol";
        };

        "custom/startmenu" = {
          tooltip = false;
          format = "😬";
          on-click = "rofi --show drun";
        };

        "battery" = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "BAT {capacity}%";
          format-charging = "BAT+ {capacity}%";
          format-plugged = "BAT+ {capacity}%";
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
          background-color: ${theme.color.background};
          border-radius: 0px;
          color: ${theme.color.accent};
        }

        #workspaces {
          border: 0px;
          font-style: normal;
          margin: 2px;
        }

        #workspaces button {
          color: ${theme.color.accent};
          border-radius: 0;
        }

        #workspaces button:hover {
          background: ${theme.color.accent};
          color: ${theme.color.background};
          border: 0px solid transparent;
        }

        #workspaces button.active {
          border: 1px solid ${theme.color.accent};
        }

        tooltip {
          border-radius: 10px;
        }

        tooltip label {
        }
      ''
    ];
  };
}
