{ lib, nix-colorizer, ... }:
let
  inherit (lib) mkOption types genAttrs;
  colorUtils = import ../utils/color.nix { inherit lib nix-colorizer; };
  mkShadeOptions =
    prefix:
    genAttrs (map (k: "${prefix}${k}") colorUtils.paletteShades) (_: mkOption { type = types.str; });
in
{
  options.skynet = {
    cli = {
      fzfThemeArgs = mkOption {
        type = types.str;
        default = "";
        description = "Common fzf theme args (style + colors) set by skynet-scripts module";
      };

      scripts = mkOption {
        type = types.listOf (
          types.submodule {
            options = {
              command = mkOption {
                type = types.listOf types.str;
                description = "Command path, e.g. ['fingerprint' 'enroll'] becomes `skynet fingerprint enroll`";
              };
              title = mkOption {
                type = types.str;
                description = "Human-readable title shown in fzf selection list";
              };
              script = mkOption {
                type = types.path;
                description = "Path to the script file (.ts or .sh)";
              };
              usage = mkOption {
                type = types.str;
                default = "";
                description = "Usage description shown below the ASCII art in preview";
              };
            };
          }
        );
        default = [ ];
        description = "Scripts registered by modules, collected into the skynet CLI";
      };
    };

    mimeapps = mkOption {
      type = types.bool;
      default = false;
    };

    theme = {
      wallpaper = mkOption {
        type = types.nullOr (types.either types.path types.package);
        default = null;
      };

      color = {
        text = mkOption { type = types.str; };

        error600 = mkOption { type = types.str; };
        error400 = mkOption { type = types.str; };
        error300 = mkOption { type = types.str; };
        error800 = mkOption { type = types.str; };
        success400 = mkOption { type = types.str; };
        success600 = mkOption { type = types.str; };
        success800 = mkOption { type = types.str; };
      }
      // (mkShadeOptions "app")
      // (mkShadeOptions "wm");

      fontFamily = {
        ui = mkOption { type = types.str; };
        uiNf = mkOption { type = types.str; };
        mono = mkOption { type = types.str; };
        monoNf = mkOption { type = types.str; };
      };

      fontSize = {
        tiny = mkOption { type = types.int; };
        small = mkOption { type = types.int; };
        normal = mkOption { type = types.int; };
        big = mkOption { type = types.int; };
        bigger = mkOption { type = types.int; };
        huge = mkOption { type = types.int; };
        humongous = mkOption { type = types.int; };
      };

      lockscreenImage = mkOption { type = types.path; };

      font = mkOption {
        type = types.attrsOf (types.attrsOf types.str);
      };
    };

    host = {
      adminUser = mkOption {
        type = types.nullOr types.str;
        default = null;
      };

      motd = {
        command = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Shell command to run as MOTD in interactive zsh sessions";
        };
      };

      ssh = {
        authorizedKeys = mkOption {
          type = types.listOf types.str;
          default = [ ];
        };
      };

      primaryMonitor = {
        width = mkOption {
          type = types.int;
          default = 1920;
        };
        height = mkOption {
          type = types.int;
          default = 1080;
        };
        hz = mkOption {
          type = types.int;
          default = 60;
        };
      };
    };

    module = {
      assorted = {
        avahi.enable = mkOption {
          type = types.bool;
          default = false;
        };
        "chrome-remote-desktop".enable = mkOption {
          type = types.bool;
          default = false;
        };
        jiratui.enable = mkOption {
          type = types.bool;
          default = false;
        };
        nchat.enable = mkOption {
          type = types.bool;
          default = false;
        };
      };
      core = {
        direnv.enable = mkOption {
          type = types.bool;
          default = true;
        };
        git.enable = mkOption {
          type = types.bool;
          default = true;
        };
        sops.enable = mkOption {
          type = types.bool;
          default = true;
        };
        "skynet-scripts".enable = mkOption {
          type = types.bool;
          default = true;
        };
        zsh.enable = mkOption {
          type = types.bool;
          default = true;
        };
      };
      desktop = {
        alacritty.enable = mkOption {
          type = types.bool;
          default = false;
        };
        csvlens.enable = mkOption {
          type = types.bool;
          default = false;
        };
        fastfetch.enable = mkOption {
          type = types.bool;
          default = false;
        };
        foot.enable = mkOption {
          type = types.bool;
          default = false;
        };
        "google-chrome".enable = mkOption {
          type = types.bool;
          default = false;
        };
        hyprland.enable = mkOption {
          type = types.bool;
          default = false;
        };
        mako.enable = mkOption {
          type = types.bool;
          default = false;
        };
        quickshell.enable = mkOption {
          type = types.bool;
          default = false;
        };
        vicinae.enable = mkOption {
          type = types.bool;
          default = false;
        };
        waybar.enable = mkOption {
          type = types.bool;
          default = false;
        };
      };
      development = {
        dnsmasq.enable = mkOption {
          type = types.bool;
          default = false;
        };
        obsidian.enable = mkOption {
          type = types.bool;
          default = false;
        };
        qemu.enable = mkOption {
          type = types.bool;
          default = false;
        };
        vscode.enable = mkOption {
          type = types.bool;
          default = false;
        };
        zeroclaw.enable = mkOption {
          type = types.bool;
          default = false;
        };
      };
      leisure = {
        minecraft.enable = mkOption {
          type = types.bool;
          default = false;
        };
        "obs-studio".enable = mkOption {
          type = types.bool;
          default = false;
        };
        spotify.enable = mkOption {
          type = types.bool;
          default = false;
        };
      };
      os = {
        fingerprint.enable = mkOption {
          type = types.bool;
          default = false;
        };
        greetd = {
          enable = mkOption {
            type = types.bool;
            default = false;
          };
          greeter = mkOption {
            type = types.enum [
              "custom"
              "tuigreet"
              "none"
            ];
            default = "custom";
            description = "Which greeter to use: 'custom' (pygame-based matching GRUB theme), 'tuigreet' (TUI-based), or 'none' (auto-login, relies on hyprlock for security)";
          };
        };
        grub.enable = mkOption {
          type = types.bool;
          default = false;
        };
        peripherals = {
          enable = mkOption {
            type = types.bool;
            default = false;
          };
          trustedDevices = mkOption {
            type = types.listOf (
              types.submodule {
                options = {
                  mac = mkOption {
                    type = types.str;
                    description = "Bluetooth MAC address, e.g. AA:BB:CC:DD:EE:FF";
                  };
                  description = mkOption {
                    type = types.str;
                    default = "";
                    description = "Human-readable label for this device";
                  };
                };
              }
            );
            default = [ ];
            description = "Bluetooth devices to auto-trust so they never trigger authorization prompts";
          };
        };
        powersaver.enable = mkOption {
          type = types.bool;
          default = false;
        };
      };
      work = {
        andamp = {
          enable = mkOption {
            type = types.bool;
            default = false;
          };
          CEFKM = mkOption {
            type = types.bool;
            default = false;
          };
        };
      };
    };
  };
}
