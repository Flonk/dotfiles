{
  lib,
  pkgs,
  nix-colorizer,
  config,
  ...
}:

let
  colorUtils = import ../../utils/color.nix {
    inherit lib;
    inherit nix-colorizer;
  };
  math = import ../../utils/math.nix { inherit lib; };

  textColor = "#ffffff";

  fontSize = {
    tiny = 7;
    small = 8;
    normal = 9;
    big = 10;
    bigger = 12;
    huge = 14;
    humongous = 20;
  };

  fontFamily = {
    ui = "DejaVu Sans Mono";
    uiNf = "DejaVuSansM Nerd Font";
    mono = "DejaVu Sans Mono";
    monoNf = "DejaVuSansM Nerd Font";
  };

  # helper: mirror numeric keys with identifier-safe aliases, e.g. "800" -> "main800"
  prefixKeys =
    prefix: attrs:
    lib.listToAttrs (
      lib.mapAttrsToList (k: v: {
        name = prefix + k;
        value = v;
      }) attrs
    );

  # --- Derive palette hues from user wallpaper (when provided) ---
  wallpaperSrc = config.skynet.theme.wallpaper;

  dominantHexColors =
    if wallpaperSrc != null then
      let
        extractedColorsFile =
          pkgs.runCommand "wallpaper-colors.json"
            {
              nativeBuildInputs = [ pkgs.imagemagick ];
            }
            ''
              magick ${wallpaperSrc} -resize 200x200! -colors 8 +dither -depth 8 -alpha off \
                -unique-colors txt:- \
                | tail -n +2 \
                | grep -oE '#[0-9A-Fa-f]{6}' \
                | head -8 \
                | awk 'BEGIN{printf "["} NR>1{printf ","} {printf "\"%s\"", $0} END{print "]"}' > $out
            '';
      in
      builtins.fromJSON (builtins.readFile extractedColorsFile)
    else
      [
        "#3b82f6"
        "#111827"
        "#1f2937"
        "#334155"
        "#64748b"
        "#0f172a"
      ];

  oklchColors = map (hex: {
    inherit hex;
    oklch = nix-colorizer.hex.to.oklch hex;
  }) dominantHexColors;

  # Pick the most chromatic color as the wallpaper's "primary" → WM
  primaryColor = builtins.foldl' (
    best: c: if c.oklch.C > best.oklch.C then c else best
  ) (builtins.head oklchColors) (builtins.tail oklchColors);

  # Pick the extracted color with the most distant hue from primary → App
  hueDist =
    a: b:
    let
      d = math.floatMod ((if a > b then a - b else b - a)) (2.0 * math.pi);
    in
    if d > math.pi then 2.0 * math.pi - d else d;

  secondaryColor = builtins.foldl' (
    best: c:
    let
      bestDist = hueDist primaryColor.oklch.h best.oklch.h;
      cDist = hueDist primaryColor.oklch.h c.oklch.h;
    in
    if cDist > bestDist then c else best
  ) (builtins.head oklchColors) (builtins.tail oklchColors);

  # WM palette: primary wallpaper hue (vivid accent)
  colorWm = colorUtils.mkPalette {
    cMax = 0.19;
    h = primaryColor.oklch.h;
  };

  # App palette: most opposite extracted hue (subdued)
  colorApp = colorUtils.mkPalette {
    cMax = 0.07;
    h = secondaryColor.oklch.h;
  };

  colorError = colorUtils.mkPalette {
    cMax = 0.22;
    h = math.toRad 30;
  };

  colorSuccess = colorUtils.mkPalette {
    cMax = 0.16;
    h = math.toRad 140;
  };

  lockscreenImage = ../../../assets/logos/andamp-amp-blue.png;
in
{
  config.skynet.theme = rec {
    color = {
      text = colorUtils.mkColorAttrs textColor;
    }
    // (prefixKeys "wm" colorWm)
    // (prefixKeys "app" colorApp)
    // (prefixKeys "error" colorError)
    // (prefixKeys "success" colorSuccess);

    inherit
      fontFamily
      fontSize
      lockscreenImage
      ;

    font = lib.mapAttrs (
      _famName: famVal: lib.mapAttrs (_sizeName: sz: "${famVal} ${toString sz}") fontSize
    ) fontFamily;
  };
}
