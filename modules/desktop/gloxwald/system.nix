{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.skynet.module.desktop.gloxwald;
  s = config.lib.stylix.colors.withHashtag;
  border = config.skynet.module.desktop.stylix.accent;
  mon = config.skynet.host.primaryMonitor;
  fontFamily = config.stylix.fonts.monospace.name;
in
{
  config = lib.mkIf cfg.enable {
    programs.gloxwald.hyprland.enable = true;

    programs.gloxwald.theme = {
      bg_base = s.base00;
      bg_active = s.base01;
      accent = border;
      fg_primary = s.base05;
    };

    programs.gloxwald.greeter = {
      enable = true;
      output = "eDP-1";
      settings = {
        exec = "start-hyprland >/dev/null 2>&1";
        user = config.skynet.host.adminUser;
      };
      font = {
        name = config.stylix.fonts.monospace.name;
        size = 20;
        package = config.stylix.fonts.monospace.package;
      };
    };

    programs.gloxwald.grub = {
      enable = true;

      resolution = {
        width = mon.width;
        height = mon.height;
      };

      font = {
        family = fontFamily;
        regular = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono.ttf";
        bold = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono-Bold.ttf";
      };
    };
  };
}
