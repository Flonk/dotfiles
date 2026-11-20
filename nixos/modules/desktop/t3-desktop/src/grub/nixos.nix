{ config, lib, pkgs, ... }:
with lib;
let
  grubCfg = config.programs.t3-desktop.grub;
  t = config.programs.t3-desktop.theme;

  asciiDefault = builtins.readFile ../../ascii.txt;

  t3Pkgs = import ../../packages.nix {
    inherit pkgs;
    accent = if t != null then t.accent else "#1d9eb6";
    frameWidth = grubCfg.resolution.width;
    frameHeight = grubCfg.resolution.height;
  };
  palette = builtins.fromJSON (builtins.readFile "${t3Pkgs.chrome}/palette.json");

  t3GrubTheme = pkgs.runCommand "t3-desktop-grub-theme"
    {
      nativeBuildInputs = with pkgs; [ imagemagick grub2 ];

      GRUB_BG_COLOR     = palette.ground;
      GRUB_BACKGROUND   = t3Pkgs.frame;
      GRUB_BORDER_COLOR = if t != null then t.accent    else "#ff9529";
      GRUB_BAR_BG       = if t != null then t.bg_active else "#1C1D24";

      GRUB_WIDTH = toString grubCfg.resolution.width;
      GRUB_HEIGHT = toString grubCfg.resolution.height;

      GRUB_ASCII_ART = pkgs.writeText "t3-desktop-ascii.txt"
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
    boot.loader.timeout = lib.mkDefault 1;
    boot.loader.grub.useOSProber = grubCfg.useOSProber;
    boot.loader.grub.theme = t3GrubTheme;
    boot.loader.grub.splashImage = "${t3GrubTheme}/terminal.png";
    boot.loader.grub.splashMode = "normal";
    boot.loader.grub.backgroundColor = palette.ground;
  };
}
