{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.programs.gloxwald.stylix;
in
{
  options.programs.gloxwald.stylix = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Stylix theming for the gloxwald desktop (requires the stylix home-manager module to be imported)";
    };

    scheme = lib.mkOption {
      type = lib.types.str;
      default = "ayu-dark";
      description = "Base16 scheme name (filename without .yaml) from base16-schemes";
    };

    accent = lib.mkOption {
      type = lib.types.str;
      default = "#ff9624";
      description = "Accent color (borders, active tabs, bar highlights)";
    };

    accentDark = lib.mkOption {
      type = lib.types.str;
      default = "#8e4e1c";
      description = "Darker accent variant (focused/inactive tab text)";
    };
  };

  config = lib.mkIf (config.programs.gloxwald.hyprland.enable && cfg.enable) (
    lib.mkMerge [
      {
        # New stylix sets gtk.gtk4.theme itself; mkForce keeps our "no GTK4 theming" intent
        # and resolves the null-vs-not-null conflict.
        gtk.gtk4.theme = lib.mkForce null;

        stylix = {
          enable = true;
          base16Scheme = "${pkgs.base16-schemes}/share/themes/${cfg.scheme}.yaml";
          cursor = {
            package = pkgs.apple-cursor;
            name = "Apple Cursor";
            size = 24;
          };
          fonts = {
            monospace = {
              package = pkgs.nerd-fonts.dejavu-sans-mono;
              name = "DejaVuSansM Nerd Font";
            };
            sansSerif = {
              package = pkgs.nerd-fonts.dejavu-sans-mono;
              name = "DejaVuSansM Nerd Font";
            };
            serif = {
              package = pkgs.nerd-fonts.dejavu-sans-mono;
              name = "DejaVuSansM Nerd Font";
            };
            sizes = {
              applications = 10;
              desktop = 10;
              popups = 10;
              terminal = 9;
            };
          };
        };
      }

      (lib.mkIf (config.programs.gloxwald.wallpaper != null) {
        stylix.image = config.programs.gloxwald.wallpaper;
      })
    ]
  );
}
