{ pkgs, lib, ... }:
with lib;
let
  asciiDefault = builtins.readFile ./ascii.txt;

  lockScript = pkgs.writeShellScript "gloxwald-lock" ''
    for i in $(seq 20); do
      ${pkgs.quickshell}/bin/quickshell ipc call lock lock && exit 0
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

    label = {
      size = mkOption {
        type = types.int;
        default = 10;
        description = "Pixel size of the T3 label text used by the chrome header, hy3 tabs and qutebrowser tabs";
      };
      tracking = mkOption {
        type = types.float;
        default = 1.2;
        description = "Letter spacing in pixels of the T3 label text";
      };
    };

    fastfetch.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Use the accent-coloured T3 mark as the fastfetch logo (only applies when fastfetch is enabled)";
    };

    starship.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Add the accent to the starship palette as `accent` (only applies when starship is enabled)";
    };

    foot = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Give foot the ground colour with transparency so the desktop ground and grain show through (only applies when foot is enabled)";
      };
      alpha = mkOption {
        type = types.float;
        default = 0.88;
        description = "Foot background opacity";
      };
    };

    qutebrowser.enable = mkOption {
      type = types.bool;
      default = true;
      description = "T3 chrome styling for qutebrowser (only applies when qutebrowser is enabled)";
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
      ground = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Desktop ground colour behind the windows, inside the chrome frame; derived from the accent when null";
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
