{
  lib,
  pkgs,
  nix-colorizer,
  ...
}:

let
  pi = 3.141592653589793;
  toRad = deg: deg * pi / 180.0;

  textColor = "#ffffff";
  backgroundColor = "#000000";
  # accentColor = "#0090b1"; # andamp blue

  accentColor = {
    L = 0.7874;
    C = 0.1715;
    # h = toRad 69.12;
    h = toRad 120.0;
    a = 1.0;
  };

  fontSize = {
    tiny = 7.5;
    small = 8;
    normal = 9;
    big = 10.5;
    bigger = 12.5;
    huge = 14;
    humongous = 20;
  };

  fontFamily = {
    ui = "DejaVu Sans Mono";
    mono = "DejaVu Sans Mono";
  };

  lockscreenImage = ../assets/logos/andamp.png;
  wallpaper = ../assets/wallpapers/out.jpg;

  _wallpaper =
    pkgs.runCommand "../assets/wallpapers/company_wallpaper.png"
      {
        buildInputs = [ pkgs.imagemagick ];
      }
      ''
        convert -size 3440x1440 canvas:"${accentColor}" \
          \( ${lockscreenImage} -channel rgba -fill black -colorize 100% -resize 150x150 \) \
          -gravity center -compose over -composite \
        $out
      '';

  chromaFactorQuad =
    {
      peakKey ? 800,
      rightKey ? 900,
      rightFactor ? 0.8,
      floor ? 0.6,
    }:
    key:
    let
      dxR = rightKey - peakKey;
      k = (1.0 - rightFactor) / (dxR * dxR);
      raw = 1.0 - k * (key - peakKey) * (key - peakKey);
    in
    lib.max floor raw;

  tailwindKeys = [
    50
    100
    150
    200
    300
    400
    500
    600
    700
    800
    900
    950
  ];

  # Palette builder: L from key/1000, C from quadratic factor * Cmax
  mkPalette =
    {
      cMax,
      h,
      lCap ? 0.99,
      keys ? tailwindKeys,
      factorFn ? chromaFactorQuad {
        peakKey = 800;
        rightKey = 900;
        rightFactor = 0.8;
        floor = 0.6;
      },
    }:
    lib.listToAttrs (
      map (
        key:
        let
          l = lib.min lCap (key / 1000.0);
          c = cMax * (factorFn key);
          col = {
            L = l;
            C = c;
            h = h;
            a = 1.0;
          };
          hex = nix-colorizer.oklch.to.hex col;
        in
        lib.nameValuePair (toString key) hex
      ) keys
    );

  colorMain = mkPalette {
    cMax = accentColor.C;
    h = accentColor.h;
  };

in
{
  color = {

    text = textColor;
    background = backgroundColor;

    accent = colorMain."800";
    main = colorMain;

    notifications = {
      backgroundColor = backgroundColor;

      low = "#333333";
      lowText = "#aaaaaa";

      normal = colorMain."800";
      normalText = textColor;

      urgent = "#ff0000";
      urgentText = textColor;
    };
  };

  fontFamily = fontFamily;
  fontSize = fontSize;

  font = lib.mapAttrs (
    famName: famVal: lib.mapAttrs (sizeName: sz: "${famVal} ${toString sz}") fontSize
  ) fontFamily;

  wallpaper = wallpaper;
  lockscreenImage = lockscreenImage;
}
