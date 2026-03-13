{
  config,
  lib,
  pkgs,
  ...
}:
let
  c = config.skynet.theme.color;
  mon = config.skynet.host.primaryMonitor;
  fontFamily = config.skynet.theme.fontFamily.mono;

  skynetGrubTheme =
    pkgs.runCommand "skynet-grub-theme"
      {
        nativeBuildInputs = with pkgs; [
          imagemagick
          grub2
        ];

        # Colors
        GRUB_BG_COLOR = c.app100.hex;
        GRUB_BORDER_COLOR = c.wm800.hex;
        GRUB_BAR_BG = c.app200.hex;
        GRUB_BAR_FG = c.app600.hex;
        GRUB_TEXT_COLOR = c.text.hex;
        GRUB_TEXT_DIM = c.app400.hex;

        # Dimensions
        GRUB_WIDTH = toString mon.width;
        GRUB_HEIGHT = toString mon.height;

        # Paths
        GRUB_LOGO = config.skynet.theme.lockscreenImage;
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
  config = lib.mkIf config.skynet.module.os.grub.enable {
    boot.loader.grub.enable = true;
    boot.loader.grub.useOSProber = true;
    boot.loader.grub.theme = skynetGrubTheme;
  };
}
