{
  config,
  lib,
  pkgs,
  ...
}:
let
  c = config.theme.color;
  mon = config.skynet.primaryMonitor;
  fontFamily = config.theme.fontFamily.mono;

  skynetGrubTheme =
    pkgs.runCommand "skynet-grub-theme"
      {
        nativeBuildInputs = with pkgs; [
          imagemagick
          grub2
        ];

        # Colors
        GRUB_BG_COLOR = c.app100;
        GRUB_BORDER_COLOR = c.wm800;
        GRUB_BAR_BG = c.app200;
        GRUB_BAR_FG = c.app600;
        GRUB_TEXT_COLOR = c.text;
        GRUB_TEXT_DIM = c.app400;

        # Dimensions
        GRUB_WIDTH = toString mon.width;
        GRUB_HEIGHT = toString mon.height;

        # Paths
        GRUB_LOGO = config.theme.lockscreenImage;
        GRUB_FONT_FAMILY = fontFamily;
        GRUB_FONT_REGULAR = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono.ttf";
        GRUB_FONT_BOLD = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono-Bold.ttf";
        GRUB_OUTPUT_DIR = "placeholder"; # overridden in buildCommand
      }
      ''
        export GRUB_OUTPUT_DIR="$out"
        mkdir -p "$out"
        bash ${./src/generate-assets.sh}
      '';
in
{
  config = lib.mkIf config.skynet.module.grub.enable {
    boot.loader.grub.enable = true;
    boot.loader.grub.useOSProber = true;
    boot.loader.grub.theme = skynetGrubTheme;
  };
}
