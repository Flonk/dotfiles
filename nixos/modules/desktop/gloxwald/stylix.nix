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
