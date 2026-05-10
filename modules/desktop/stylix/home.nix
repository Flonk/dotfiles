{
  pkgs,
  config,
  lib,
  ...
}:
let
  scheme = config.skynet.module.desktop.stylix.scheme;
  enabled = config.skynet.module.desktop.stylix.enable;
  wallpaper = config.skynet.module.desktop.stylix.wallpaper;
in
{
  config = lib.mkMerge [
    {
      stylix.enable = enabled;
      stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/${scheme}.yaml";
    }
    (lib.mkIf enabled {
      gtk.gtk4.theme = null;

      stylix = {
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
    })
    (lib.mkIf (enabled && wallpaper != null) {
      stylix.image = wallpaper;
    })
  ];
}
