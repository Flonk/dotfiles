{
  pkgs,
  config,
  lib,
  ...
}:
let
  scheme = config.skynet.module.desktop.stylix.scheme;
in
{
  config = lib.mkIf config.skynet.module.desktop.stylix.enable {
    gtk.gtk4.theme = null;

    stylix = {
      enable = true;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/${scheme}.yaml";
      image = config.skynet.theme.wallpaper;
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
          package = pkgs.dejavu_fonts;
          name = "DejaVu Sans";
        };
        serif = {
          package = pkgs.dejavu_fonts;
          name = "DejaVu Serif";
        };
        sizes = {
          applications = 9;
          desktop = 9;
          popups = 9;
          terminal = 9;
        };
      };
    };
  };
}
