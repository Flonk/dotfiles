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

  # --- Derive palette hues from wallpaper's dominant color (IFD) ---
  wallpaperSrc = ../../../assets/wallpapers/wallhaven-o5qwl7.jpg;

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

  dominantHexColors = builtins.fromJSON (builtins.readFile extractedColorsFile);

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

  colorError600 = nix-colorizer.oklch.to.hex {
    L = 0.56;
    C = 0.22;
    h = math.toRad 30;
    a = 1.0;
  };

  colorError400 = nix-colorizer.oklch.to.hex {
    L = 0.4;
    C = 0.16;
    h = math.toRad 30;
    a = 1.0;
  };

  colorError300 = nix-colorizer.oklch.to.hex {
    L = 0.3;
    C = 0.11;
    h = math.toRad 30;
    a = 1.0;
  };

  colorError800 = nix-colorizer.oklch.to.hex {
    L = 0.8;
    C = 0.16;
    h = math.toRad 30;
    a = 1.0;
  };

  # Success color palette
  colorSuccess400 = nix-colorizer.oklch.to.hex {
    L = 0.4;
    C = 0.15; # 0.135 * 0.39 * 2.8 (approximate scaling)
    h = math.toRad 140;
    a = 1.0;
  };

  colorSuccess600 = nix-colorizer.oklch.to.hex {
    L = 0.60;
    C = 0.135;
    h = math.toRad 140;
    a = 1.0;
  };

  colorSuccess800 = nix-colorizer.oklch.to.hex {
    L = 0.8;
    C = 0.16; # bit more chroma than 600
    h = math.toRad 140;
    a = 1.0;
  };

  lockscreenImage = ../../../assets/logos/andamp-amp-blue.png;
  # wallpaper = (import ./wallpaper.nix) {
  #   inherit
  #     lib
  #     pkgs
  #     config
  #     colorWm
  #     colorApp
  #     colorUtils
  #     lockscreenImage
  #     colorError600
  #     colorError400
  #     colorError300
  #     colorError800
  #     colorSuccess400
  #     colorSuccess600
  #     colorSuccess800
  #     ;
  # };
  wallpaper = pkgs.runCommand "wallpaper.jpg" { } ''
    cp ${wallpaperSrc} $out
  '';

in
{
  config.theme = rec {
    color = {
      text = textColor;

      error600 = colorError600;
      error400 = colorError400;
      error300 = colorError300;
      error800 = colorError800;
      success400 = colorSuccess400;
      success600 = colorSuccess600;
      success800 = colorSuccess800;
    }
    // (prefixKeys "wm" colorWm)
    // (prefixKeys "app" colorApp);

    inherit
      fontFamily
      fontSize
      wallpaper
      lockscreenImage
      ;

    font = lib.mapAttrs (
      _famName: famVal: lib.mapAttrs (_sizeName: sz: "${famVal} ${toString sz}") fontSize
    ) fontFamily;
  };
}
