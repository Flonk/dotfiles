{ config, lib, pkgs, ... }:
with lib;
let
  grubCfg = config.programs.gloxwald.grub;
  t = config.programs.gloxwald.theme;

  asciiDefault = builtins.readFile ../../ascii.txt;

  gloxwaldPkgs = import ../../packages.nix {
    inherit pkgs;
    accent = if t != null then t.accent else "#1d9eb6";
    frameWidth = grubCfg.resolution.width;
    frameHeight = grubCfg.resolution.height;
  };
  palette = builtins.fromJSON (builtins.readFile "${gloxwaldPkgs.chrome}/palette.json");

  gloxwaldGrubTheme = pkgs.runCommand "gloxwald-grub-theme"
    {
      nativeBuildInputs = with pkgs; [ imagemagick grub2 ];

      GRUB_BG_COLOR     = palette.ground;
      GRUB_BACKGROUND   = gloxwaldPkgs.frame;
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
