{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet = {
    mimeapps = mkOption {
      type = types.bool;
      default = false;
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
        skynet-scripts = mkOption {
          type = types.bool;
          default = false;
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
      };
    };
  };
}
