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
  backgroundColor = "#0B0C08";

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
    pkgs.runCommand "../assets/wallpapers/company_wallpaper.png" { buildInputs = [ pkgs.imagemagick ]; }
      ''
        convert -size 3440x1440 canvas:"${accentColor}" \
          \( ${lockscreenImage} -channel rgba -fill black -colorize 100% -resize 150x150 \) \
          -gravity center -compose over -composite \
        $out
      '';

  chromaPoints = [
    {
      k = 50;
      v = 0.02;
    }
    {
      k = 100;
      v = 0.03;
    }
    {
      k = 150;
      v = 0.04;
    }
    {
      k = 200;
      v = 0.11;
    }
    {
      k = 300;
      v = 0.26;
    }
    {
      k = 400;
      v = 0.39;
    }
    {
      k = 500;
      v = 0.57;
    }
    {
      k = 600;
      v = 0.75;
    }
    {
      k = 700;
      v = 0.90;
    }
    {
      k = 800;
      v = 1.00;
    }
    {
      k = 900;
      v = 0.95;
    }
    {
      k = 950;
      v = 0.80;
    }
  ];

  mkPaletteFromPoints =
    {
      cMax,
      h,
      lCap ? 0.99,
      points ? chromaPoints,
    }:
    lib.listToAttrs (
      map (
        p:
        let
          l = lib.min lCap (p.k / 1000.0);
          c = cMax * p.v;
          hex = nix-colorizer.oklch.to.hex {
            L = l;
            C = c;
            h = h;
            a = 1.0;
          };
        in
        lib.nameValuePair (toString p.k) hex
      ) points
    );

  # helper: mirror numeric keys with identifier-safe aliases, e.g. "800" -> "main800"
  prefixKeys =
    prefix: attrs:
    lib.listToAttrs (
      lib.mapAttrsToList (k: v: {
        name = prefix + k;
        value = v;
      }) attrs
    );

  colorMain = mkPaletteFromPoints {
    cMax = accentColor.C;
    h = accentColor.h;
  };

  floatMod =
    a: b:
    let
      r = builtins.floor (a / b);
    in
    a - r * b;

  colorOpp = mkPaletteFromPoints {
    cMax = 0.13;
    h = floatMod (accentColor.h + pi) (2.0 * pi);
  };

in
rec {
  color =
    {
      text = textColor;
      background = colorMain."150";

      wm = colorMain;
      app = colorOpp;

      notifications = {
        backgroundColor = colorMain."150";

        low = "#333333";
        lowText = "#aaaaaa";

        normal = colorMain."800";
        normalText = textColor;

        urgent = "#ff0000";
        urgentText = textColor;
      };
    }
    // (prefixKeys "wm" colorMain)
    // (prefixKeys "app" colorOpp);

  inherit
    fontFamily
    fontSize
    wallpaper
    lockscreenImage
    ;

  font = lib.mapAttrs (
    _famName: famVal: lib.mapAttrs (_sizeName: sz: "${famVal} ${toString sz}") fontSize
  ) fontFamily;
}
