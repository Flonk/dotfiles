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
  backgroundColor = "#0B0C08";

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

  mainC = 0.19;
  # mainH = math.toRad 162.0; # mint
  mainH = math.toRad 110.0; # lime
  # mainH = math.toRad 256.0; # blue
  # mainH = math.toRad 50.0; # trump

  colorWm = colorUtils.mkPalette {
    cMax = mainC;
    h = mainH;
  };

  colorApp = colorUtils.mkPalette {
    cMax = 0.07;
    h = math.floatMod (mainH + math.pi) (2.0 * math.pi);
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

  lockscreenImage = ../../../assets/logos/andamp.png;
  wallpaper = (import ./wallpaper.nix) {
    inherit
      lib
      pkgs
      config
      colorWm
      colorApp
      colorUtils
      lockscreenImage
      colorError600
      colorError400
      colorError300
      ;
  };

in
{
  config.theme = rec {
    color = {
      text = textColor;

      error600 = colorError600;
      error400 = colorError400;
      error300 = colorError300;
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
