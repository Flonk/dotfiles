{ lib, nix-colorizer, ... }:
let
  inherit (lib) mkOption types genAttrs;
  colorUtils = import ../utils/color.nix { inherit lib nix-colorizer; };

  colorType = types.submodule {
    options = {
      hex = mkOption { type = types.str; };
      hexNoHash = mkOption { type = types.str; };
      hexAlpha = mkOption { type = types.str; };
      rgba = mkOption { type = types.str; };
      hexRgb = mkOption { type = types.str; };
      hexRgba = mkOption { type = types.str; };
      hex0x = mkOption { type = types.str; };
      r = mkOption { type = types.int; };
      g = mkOption { type = types.int; };
      b = mkOption { type = types.int; };
      a = mkOption { type = types.number; };
      ansi = mkOption { type = types.str; };
      ansiBackground = mkOption { type = types.str; };
    };
  };

  mkShadeOptions =
    prefix:
    genAttrs (map (k: "${prefix}${k}") colorUtils.paletteShades) (_: mkOption { type = colorType; });
in
{
  options.skynet.theme = {
    wallpaper = mkOption {
      type = types.nullOr (types.either types.path types.package);
      default = null;
    };

    color = {
      text = mkOption { type = colorType; };
    }
    // (mkShadeOptions "app")
    // (mkShadeOptions "wm")
    // (mkShadeOptions "error")
    // (mkShadeOptions "success");

    fontFamily = {
      ui = mkOption { type = types.str; };
      uiNf = mkOption { type = types.str; };
      mono = mkOption { type = types.str; };
      monoNf = mkOption { type = types.str; };
    };

    fontSize = {
      tiny = mkOption { type = types.int; };
      small = mkOption { type = types.int; };
      normal = mkOption { type = types.int; };
      big = mkOption { type = types.int; };
      bigger = mkOption { type = types.int; };
      huge = mkOption { type = types.int; };
      humongous = mkOption { type = types.int; };
    };

    lockscreenImage = mkOption { type = types.path; };

    font = mkOption {
      type = types.attrsOf (types.attrsOf types.str);
    };
  };
}
