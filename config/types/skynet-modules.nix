{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module = {
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
      "claude-code".enable = mkOption {
        type = types.bool;
        default = false;
      };
      "claude-cowork".enable = mkOption {
        type = types.bool;
        default = false;
      };
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
        CEIFRS = mkOption {
          type = types.bool;
          default = false;
        };
      };
    };
  };
}
