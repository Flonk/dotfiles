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
      alacritty.enable = mkOption {
        type = types.bool;
        default = false;
      };
      antigravity.enable = mkOption {
        type = types.bool;
        default = false;
      };
      avahi.enable = mkOption {
        type = types.bool;
        default = false;
      };
      chrome-remote-desktop.enable = mkOption {
        type = types.bool;
        default = false;
      };
      csvlens.enable = mkOption {
        type = types.bool;
        default = false;
      };
      direnv.enable = mkOption {
        type = types.bool;
        default = false;
      };
      dnsmasq.enable = mkOption {
        type = types.bool;
        default = false;
      };
      fastfetch.enable = mkOption {
        type = types.bool;
        default = false;
      };
      fingerprint.enable = mkOption {
        type = types.bool;
        default = false;
      };
      foot.enable = mkOption {
        type = types.bool;
        default = false;
      };
      git.enable = mkOption {
        type = types.bool;
        default = false;
      };
      google-chrome.enable = mkOption {
        type = types.bool;
        default = false;
      };
      greetd.enable = mkOption {
        type = types.bool;
        default = false;
      };
      grub.enable = mkOption {
        type = types.bool;
        default = false;
      };
      hyprland.enable = mkOption {
        type = types.bool;
        default = false;
      };
      jiratui.enable = mkOption {
        type = types.bool;
        default = false;
      };
      mako.enable = mkOption {
        type = types.bool;
        default = false;
      };
      minecraft.enable = mkOption {
        type = types.bool;
        default = false;
      };
      nchat.enable = mkOption {
        type = types.bool;
        default = false;
      };
      obs-studio.enable = mkOption {
        type = types.bool;
        default = false;
      };
      obsidian.enable = mkOption {
        type = types.bool;
        default = false;
      };
      ollama.enable = mkOption {
        type = types.bool;
        default = false;
      };
      openclaw.enable = mkOption {
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
      qemu.enable = mkOption {
        type = types.bool;
        default = false;
      };
      quickshell.enable = mkOption {
        type = types.bool;
        default = false;
      };
      spotify.enable = mkOption {
        type = types.bool;
        default = false;
      };
      vscode.enable = mkOption {
        type = types.bool;
        default = false;
      };
      walker.enable = mkOption {
        type = types.bool;
        default = false;
      };
      waybar.enable = mkOption {
        type = types.bool;
        default = false;
      };
      zsh.enable = mkOption {
        type = types.bool;
        default = false;
      };
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
}
