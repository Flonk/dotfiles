{
  pkgs,
  config,
  lib,
  theme,
  ...
}: {
  
  home.pointerCursor = {
    package = pkgs.apple-cursor;
    name = "Apple Cursor";
    size = 24;

    hyprcursor = {
      enable = true;
      size = config.home.pointerCursor.size;
    };

    gtk.enable = true;
  };

}
