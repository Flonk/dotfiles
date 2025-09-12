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

  mkPalette =
    {
      c,
      h,
      lCap ? 0.99,
    }:
    lib.listToAttrs (
      map
        (
          key:
          let
            l = lib.min lCap (key / 1000.0);
            col = {
              L = l;
              C = c;
              h = h;
              a = 1.0;
            };
            hex = nix-colorizer.oklch.to.hex col;
          in
          lib.nameValuePair (toString key) hex
        )
        [
          50
          100
          200
          300
          400
          500
          600
          700
          800
          900
          950
        ]
    );

  colorMain = mkPalette {
    c = accentColor.C;
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
