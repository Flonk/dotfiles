{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet = {
    cli = {
      scripts = mkOption {
        type = types.listOf (
          types.submodule {
            options = {
              command = mkOption {
                type = types.listOf types.str;
                description = "Command path, e.g. ['fingerprint' 'enroll'] becomes `skynet fingerprint enroll`";
              };
              description = mkOption {
                type = types.str;
                description = "Human-readable description shown in help and fzf UI";
              };
              script = mkOption {
                type = types.path;
                description = "Path to the script file (.ts or .sh)";
              };
              preview = mkOption {
                type = types.str;
                default = "";
                description = "Optional shell command for fzf preview pane";
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

    discordId = mkOption {
      type = types.str;
      default = "";
      description = "Discord user ID for allow-listing in OpenClaw";
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

    module = {
      home = {
        alacritty = mkOption {
          type = types.bool;
          default = false;
        };
        csvlens = mkOption {
          type = types.bool;
          default = false;
        };
        direnv = mkOption {
          type = types.bool;
          default = false;
        };
        fastfetch = mkOption {
          type = types.bool;
          default = false;
        };
        foot = mkOption {
          type = types.bool;
          default = false;
        };
        git = mkOption {
          type = types.bool;
          default = false;
        };
        google-chrome = mkOption {
          type = types.bool;
          default = false;
        };
        hyprland = mkOption {
          type = types.bool;
          default = false;
        };
        jiratui = mkOption {
          type = types.bool;
          default = false;
        };
        mako = mkOption {
          type = types.bool;
          default = false;
        };
        minecraft = mkOption {
          type = types.bool;
          default = false;
        };
        nchat = mkOption {
          type = types.bool;
          default = false;
        };
        openclaw = mkOption {
          type = types.bool;
          default = false;
        };
        obs-studio = mkOption {
          type = types.bool;
          default = false;
        };
        obsidian = mkOption {
          type = types.bool;
          default = false;
        };
        powersaver = mkOption {
          type = types.bool;
          default = false;
        };
        quickshell = mkOption {
          type = types.bool;
          default = false;
        };
        spotify = mkOption {
          type = types.bool;
          default = false;
        };
        vscode = mkOption {
          type = types.bool;
          default = false;
        };
        walker = mkOption {
          type = types.bool;
          default = false;
        };
        waybar = mkOption {
          type = types.bool;
          default = false;
        };
        zsh = mkOption {
          type = types.bool;
          default = false;
        };

        antigravity = mkOption {
          type = types.bool;
          default = false;
        };
        peripherals = {
          enabled = mkOption {
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
      };

      work = {
        andamp = {
          enabled = mkOption {
            type = types.bool;
            default = false;
          };
          CEFKM = mkOption {
            type = types.bool;
            default = false;
          };
        };
      };

      system = {
        avahi = mkOption {
          type = types.bool;
          default = false;
        };
        chrome-remote-desktop = mkOption {
          type = types.bool;
          default = false;
        };
        dnsmasq = mkOption {
          type = types.bool;
          default = false;
        };
        fingerprint = mkOption {
          type = types.bool;
          default = false;
        };
        greetd = mkOption {
          type = types.bool;
          default = false;
        };
        grub = mkOption {
          type = types.bool;
          default = false;
        };
        powersaver = mkOption {
          type = types.bool;
          default = false;
        };
        qemu = mkOption {
          type = types.bool;
          default = false;
        };
        ollama = mkOption {
          type = types.bool;
          default = false;
        };
      };
    };
  };
}
