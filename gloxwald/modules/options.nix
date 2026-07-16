{ pkgs, lib, ... }:
with lib;
let
  asciiDefault = builtins.readFile ../ascii.txt;

  lockScript = pkgs.writeShellScript "gloxwald-lock" ''
    uid=$(id -u)
    for i in $(seq 20); do
      id=$(ls -t /run/user/"$uid"/quickshell/by-id/ 2>/dev/null | head -1)
      if [ -n "$id" ]; then
        ${pkgs.quickshell}/bin/quickshell ipc -i "$id" call lock lock && exit 0
      fi
      sleep 0.5
    done
    exit 1
  '';
in
{
  options.programs.gloxwald = {

    # --- home-manager ---

    hyprland.enable = mkEnableOption "gloxwald hyprland session";

    quickshell = {
      enable = mkEnableOption "gloxwald quickshell bar and lockscreen";

      lockCommand = mkOption {
        type = types.str;
        readOnly = true;
        default = "${lockScript}";
        description = "Command to lock the screen via quickshell IPC. Use this in hyprland binds etc.";
      };
    };

    stylix = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Stylix theming for the gloxwald desktop (requires the stylix home-manager module to be imported)";
      };
      scheme = mkOption {
        type = types.str;
        default = "ayu-dark";
        description = "Base16 scheme name (filename without .yaml) from base16-schemes";
      };
      accent = mkOption {
        type = types.str;
        default = "#ff9624";
        description = "Accent color (borders, active tabs, bar highlights)";
      };
      accentDark = mkOption {
        type = types.str;
        default = "#8e4e1c";
        description = "Darker accent variant (focused/inactive tab text)";
      };
    };

    wallpaper = mkOption {
      type = types.nullOr (types.either types.path types.package);
      default = null;
      description = "Wallpaper image; served by stylix when enabled, otherwise via hyprpaper";
    };

    vicinae.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Ship the vicinae launcher (requires the vicinae home-manager module to be imported)";
    };

    mako.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Ship the mako notification daemon";
    };

    i18n = {
      enable = mkEnableOption "fcitx5 input-method switching (gloxwald-i18n CLI, bar widget, MOD3+I cycle)";

      defaultLayout = mkOption {
        type = types.str;
        default = "us";
      };

      inputMethods = mkOption {
        type = types.listOf (
          types.submodule {
            options = {
              im = mkOption { type = types.str; };
              label = mkOption { type = types.str; };
              layout = mkOption {
                type = types.str;
                default = "";
              };
            };
          }
        );
        default = [
          {
            im = "keyboard-us";
            label = "ENGLISH";
          }
        ];
      };
    };

    # --- nixos ---

    theme = mkOption {
      type = types.nullOr (
        types.submodule {
          options = {
            asciiArt = mkOption {
              type = types.lines;
              default = asciiDefault;
              description = "ASCII art displayed by greeter and rendered into the GRUB background";
            };
            bg_base = mkOption { type = types.str; };
            bg_active = mkOption { type = types.str; };
            accent = mkOption { type = types.str; };
            fg_primary = mkOption { type = types.str; };
          };
        }
      );
      default = null;
      description = "Shared theme for greeter and GRUB. If null, hardcoded defaults are used.";
    };

    greeter = {
      enable = mkEnableOption "gloxwaldgreet greeter for greetd";

      output = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "eDP-1";
        description = ''
          Wayland output to pin the greeter to (e.g. "eDP-1"). When null the
          greeter runs under cage and spans all connected outputs, which on a
          multi-monitor setup centres it across the seam between displays. When
          set, the greeter runs under sway on that single output only.
        '';
      };

      settings = {
        exec = mkOption {
          type = types.str;
          description = "Command to launch after successful login (e.g. \"start-hyprland\")";
        };
        user = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Username to prefill; initial focus moves to the password field";
        };
      };

      font = {
        name = mkOption {
          type = types.str;
          default = "monospace";
          description = "Font name for the greeter (rendered via kitty)";
        };
        size = mkOption {
          type = types.int;
          default = 18;
          description = "Font size in points for the greeter";
        };
        package = mkOption {
          type = types.nullOr types.package;
          default = null;
          description = "Font package to install (e.g. pkgs.nerd-fonts.dejavu-sans-mono)";
        };
      };
    };

    grub = {
      enable = mkEnableOption "gloxwald GRUB theme";

      resolution = {
        width = mkOption {
          type = types.int;
          default = 1920;
        };
        height = mkOption {
          type = types.int;
          default = 1080;
        };
      };

      font = {
        family = mkOption {
          type = types.str;
          default = "DejaVu Sans Mono";
          description = "Font family name used in theme.txt";
        };
        regular = mkOption {
          type = types.path;
          default = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono.ttf";
          description = "Path to regular weight TTF";
        };
        bold = mkOption {
          type = types.path;
          default = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono-Bold.ttf";
          description = "Path to bold weight TTF";
        };
      };

      useOSProber = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable os-prober for detecting other OSes";
      };
    };
  };
}
