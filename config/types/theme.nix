{ lib, nix-colorizer, ... }:
let
  inherit (lib) mkOption types genAttrs;
  # Import shared chroma keys
  colorUtils = import ../utils/color.nix { inherit lib nix-colorizer; };
  mkShadeOptions =
    prefix:
    genAttrs (map (k: "${prefix}${k}") colorUtils.paletteShades) (_: mkOption { type = types.str; });
in
{
  options.theme = {
    color =
      {
        text = mkOption { type = types.str; };

        error600 = mkOption { type = types.str; };
        error400 = mkOption { type = types.str; };
        error300 = mkOption { type = types.str; };
      }
      // (mkShadeOptions "app")
      // (mkShadeOptions "wm");

    fontFamily = {
      ui = mkOption { type = types.str; };
      mono = mkOption { type = types.str; };
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

    wallpaper = mkOption { type = types.package; };
    lockscreenImage = mkOption { type = types.path; };

    font = mkOption {
      type = types.attrsOf (types.attrsOf types.str);
    };
  };
}
