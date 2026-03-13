{ lib, nix-colorizer, ... }:
rec {
  paletteChromaKeys = [
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

  paletteShades = builtins.map (p: builtins.toString p.k) paletteChromaKeys;

  hexDigitToInt =
    c:
    {
      "0" = 0;
      "1" = 1;
      "2" = 2;
      "3" = 3;
      "4" = 4;
      "5" = 5;
      "6" = 6;
      "7" = 7;
      "8" = 8;
      "9" = 9;
      "a" = 10;
      "b" = 11;
      "c" = 12;
      "d" = 13;
      "e" = 14;
      "f" = 15;
      "A" = 10;
      "B" = 11;
      "C" = 12;
      "D" = 13;
      "E" = 14;
      "F" = 15;
    }
    .${c};

  hexPairToInt =
    s:
    (hexDigitToInt (builtins.substring 0 1 s)) * 16
    + (hexDigitToInt (builtins.substring 1 1 s));

  mkColorAttrs =
    hex:
    let
      raw = lib.removePrefix "#" hex;
      lower = lib.toLower raw;
      r = hexPairToInt (builtins.substring 0 2 raw);
      g = hexPairToInt (builtins.substring 2 2 raw);
      b = hexPairToInt (builtins.substring 4 2 raw);
    in
    {
      hex = "#${lower}";
      hexNoHash = lower;
      hexAlpha = "#${lower}ff";
      rgba = "rgba(${toString r}, ${toString g}, ${toString b}, 1)";
      hexRgb = "rgb(${lower})";
      hexRgba = "rgba(${lower}ff)";
      hex0x = "0x${lower}";
      inherit r g b;
      a = 1;
      ansi = "\\e[38;2;${toString r};${toString g};${toString b}m";
      ansiBackground = "\\e[48;2;${toString r};${toString g};${toString b}m";
    };

  mkPalette =
    {
      cMax,
      h,
    }:
    lib.listToAttrs (
      map (
        p:
        let
          l = lib.min 0.99 (p.k / 1000.0);
          c = cMax * p.v;
          hex = nix-colorizer.oklch.to.hex {
            L = l;
            C = c;
            h = h;
            a = 1.0;
          };
        in
        lib.nameValuePair (toString p.k) (mkColorAttrs hex)
      ) paletteChromaKeys
    );

}
