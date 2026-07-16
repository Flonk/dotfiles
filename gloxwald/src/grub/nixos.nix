{ config, lib, pkgs, ... }:
with lib;
let
  grubCfg = config.programs.gloxwald.grub;
  t = config.programs.gloxwald.theme;

  asciiDefault = builtins.readFile ../../ascii.txt;

  gloxwaldGrubTheme = pkgs.runCommand "gloxwald-grub-theme"
    {
      nativeBuildInputs = with pkgs; [ imagemagick grub2 ];

      GRUB_BG_COLOR     = if t != null then t.bg_base   else "#1a1a1a";
      GRUB_BORDER_COLOR = if t != null then t.accent    else "#ff9529";
      GRUB_BAR_BG       = if t != null then t.bg_active else "#1C1D24";

      GRUB_WIDTH = toString grubCfg.resolution.width;
      GRUB_HEIGHT = toString grubCfg.resolution.height;

      GRUB_ASCII_ART = pkgs.writeText "gloxwald-ascii.txt"
        (if t != null then t.asciiArt else asciiDefault);
      GRUB_FONT_FAMILY = grubCfg.font.family;
      GRUB_FONT_REGULAR = grubCfg.font.regular;
      GRUB_FONT_BOLD = grubCfg.font.bold;
      GRUB_OUTPUT_DIR = "placeholder";
    }
    ''
      export GRUB_OUTPUT_DIR="$out"
      mkdir -p "$out"
      bash ${./generate-assets.sh}
    '';

in
{
  config = mkIf grubCfg.enable {
    boot.loader.grub.enable = true;
    boot.loader.grub.useOSProber = grubCfg.useOSProber;
    boot.loader.grub.theme = gloxwaldGrubTheme;
  };
}
