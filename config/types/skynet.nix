{ lib, ... }:
let
  inherit (lib) mkOption types;
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

    wallpaper = mkOption {
      type = types.nullOr (types.either types.path types.package);
      default = null;
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
          default = false;
        };
        git.enable = mkOption {
          type = types.bool;
          default = false;
        };
        sops.enable = mkOption {
          type = types.bool;
          default = false;
        };
        "skynet-scripts".enable = mkOption {
          type = types.bool;
          default = false;
        };
        zsh.enable = mkOption {
          type = types.bool;
          default = false;
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
