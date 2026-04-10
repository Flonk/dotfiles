{
  config,
  lib,
  pkgs,
  ...
}:
let
  s = config.lib.stylix.colors.withHashtag;
  border = config.skynet.module.desktop.stylix.accent;
  mon = config.skynet.host.primaryMonitor;
  fontFamily = config.stylix.fonts.monospace.name;

  skynetGrubTheme =
    pkgs.runCommand "skynet-grub-theme"
      {
        nativeBuildInputs = with pkgs; [
          imagemagick
          grub2
        ];

        # Colors
        GRUB_BG_COLOR = s.base00;
        GRUB_BORDER_COLOR = border;
        GRUB_BAR_BG = s.base01;
        GRUB_BAR_FG = s.base04;
        GRUB_TEXT_COLOR = s.base05;
        GRUB_TEXT_DIM = s.base03;
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
