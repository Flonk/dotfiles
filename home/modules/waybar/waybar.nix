{
  pkgs,
  config,
  lib,
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

        modules-center = [
        ];

        modules-left = [
        ];

        modules-right = [
          "pulseaudio"
          "battery"
          "custom/label-bat"
          "clock"
        ];

        "clock" = {
          interval = 1;
          format = ''{:%Y-%m-%d %H:%M:%S}'';
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
          background-color: ${config.theme.color.app150};
          border-radius: 0px;
          color: ${config.theme.color.wm800};
          border-top: 2px solid ${config.theme.color.app200};
        }

        #workspaces {
          border: 0px;
          font-style: normal;
          margin: 2px;
        }

        #workspaces button {
          color: ${config.theme.color.wm800};
          border-radius: 0;
        }

        #workspaces button:hover {
          background: ${config.theme.color.wm800};
          color: ${config.theme.color.wm150};
          border: 0px solid transparent;
        }

        #workspaces button.active {
          border: 1px solid ${config.theme.color.wm800};
        }

        tooltip {
          border-radius: 10px;
        }

        tooltip label {
        }

        #cava {
          color: ${config.theme.color.wm800};
        }

        #mpris, #window, #clock {
          color: ${config.theme.color.app600};
        }

        #cpu, #memory, #battery {
          margin: 0;
          padding: 0;
        }

        #custom-label-cpu, #custom-label-mem, #custom-label-bat {
          color: ${config.theme.color.app600};
          margin-right: 12px;
        }
      ''
    ];
  };
}
