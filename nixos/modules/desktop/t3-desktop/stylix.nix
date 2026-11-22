{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.programs.t3-desktop.stylix;
  t3Pkgs = import ./packages.nix {
    inherit pkgs;
    inherit (cfg) accent ground scheme;
  };
in
{
  config = lib.mkIf (config.programs.t3-desktop.hyprland.enable && cfg.enable) (
    lib.mkMerge [
      {
        gtk.gtk4.theme = lib.mkForce null;

        stylix = {
          enable = true;
          base16Scheme = if cfg.accentScheme then "${t3Pkgs.accentScheme}" else "${pkgs.base16-schemes}/share/themes/${cfg.scheme}.yaml";
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

      (lib.mkIf (config.programs.t3-desktop.wallpaper != null) {
        stylix.image = config.programs.t3-desktop.wallpaper;
      })
    ]
  );
}
