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
          "pulseaudio"
          "cava"
          "mpris"
        ];
        modules-left = [
          "custom/startmenu"
          "hyprland/workspaces"
          "hyprland/window"
        ];
        modules-right = [
          "cpu"
          "custom/label-cpu"
          "memory"
          "custom/label-mem"
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

        "cava" = {
          framerate = 30;
          autosens = 1;
          sensitivity = 3;
          bars = 16;
          lower_cutoff_freq = 50;
          higher_cutoff_freq = 10000;
          hide_on_silence = false;
          # "format_silent" = "quiet";
          method = "pulse";
          source = "auto";
          stereo = false;
          noise_reduction = 0.3;
          bar_delimiter = 0;
          input_delay = 0.25;
          format-icons = [
            " "
            "▂"
            "▃"
            "▄"
            "▅"
            "▆"
            "▇"
            "█"
          ];
        };

        "mpris" = {
          format = "{artist} - {title}";
          max-length = 40;
          on-click = "playerctl play-pause";
          on-scroll-up = "playerctl next";
          on-scroll-down = "playerctl previous";
        };

        "clock" = {
          interval = 1;
          format = ''{:%Y-%m-%d %H:%M:%S}'';
        };

        "hyprland/window" = {
          max-length = 40;
          separate-outputs = false;
        };

        "memory" = {
          interval = 5;
          format = "{}%";
        };

        "cpu" = {
          interval = 5;
          format = "{usage:2}%";
        };

        "tray" = {
          spacing = 12;
        };

        "pulseaudio" = {
          format = "{volume}%";
          on-click = "pavucontrol";
        };

        "custom/label-cpu" = {
          format = "CPU";
          tooltip = false;
        };

        "custom/label-mem" = {
          format = "MEM";
          tooltip = false;
        };

        "custom/label-bat" = {
          format = "BAT";
          tooltip = false;
        };

        "custom/startmenu" = {
          tooltip = false;
          format = "😬";
          on-click = "walker -t mytheme";
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
