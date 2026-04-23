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
      bitwarden.enable = mkOption {
        type = types.bool;
        default = false;
      };
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
      keyring.enable = mkOption {
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
      skynetlock = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        theme = mkOption {
          type = types.str;
          default = "";
          description = "Shader theme for the lock screen (e.g. 'mobius_spiral'. Keep empty for random)";
        };
      };
      stylix = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        scheme = mkOption {
          type = types.str;
          default = "ayu-dark";
          description = "Base16 scheme name (filename without .yaml) from base16-schemes";
        };
        accent = mkOption {
          type = types.str;
          default = "#ff9624";
          description = "Window manager accent color (borders, active tabs)";
        };
        accentDark = mkOption {
          type = types.str;
          default = "#8e4e1c";
          description = "Darker accent variant (focused/inactive tab text)";
        };
        wallpaper = mkOption {
          type = types.nullOr (types.either types.path types.package);
          default = null;
          description = "Wallpaper image path";
        };
        lockscreenImage = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Lockscreen / logo image path";
        };
        fontSizePx = mkOption {
          type = types.int;
          default = 14;
          description = "Base font size in pixels for apps that use pixel-based sizing (e.g. Zed, VSCode)";
        };
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
      "zed-editor".enable = mkOption {
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
      ipu6 = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        platform = mkOption {
          type = types.enum [
            "ipu6"
            "ipu6ep"
            "ipu6epmtl"
          ];
          default = "ipu6epmtl";
          description = "IPU6 platform variant: ipu6 (Tiger Lake), ipu6ep (Alder/Raptor Lake), ipu6epmtl (Meteor Lake)";
        };
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
      "network-scripts".enable = mkOption {
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
    projects = {
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
      personal = {
        dwain = {
          enable = mkOption {
            type = types.bool;
            default = false;
          };
        };
      };
    };
  };
}
