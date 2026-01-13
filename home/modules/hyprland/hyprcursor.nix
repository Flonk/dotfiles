{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.home.hyprland {
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
  };
}
