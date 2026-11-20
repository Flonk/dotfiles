{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.desktop.stylix = {
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
      type = types.nullOr types.str;
      default = null;
      description = "Darker accent variant (focused/inactive tab text); derived from accent when null";
    };
    ground = mkOption {
      type = types.str;
      default = "#100e0a";
      description = "Desktop ground colour behind the windows, inside the chrome frame";
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
}
