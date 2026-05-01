{
  config,
  lib,
  pkgs,
  ...
}:
let
  mon = config.skynet.host.primaryMonitor;
  fontFamily = config.stylix.fonts.monospace.name;
in
{
  config = lib.mkIf config.skynet.module.os.grub.enable {
    programs.skynetshell.grub = {
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
