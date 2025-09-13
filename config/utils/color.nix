{ lib, nix-colorizer, ... }:
rec {
  paletteChromaKeys = [
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
      k = 250;
      v = 0.185;
    }
    {
      k = 300;
      v = 0.26;
    }
    {
      k = 350;
      v = 0.325;
    }
    {
      k = 400;
      v = 0.39;
    }
    {
      k = 450;
      v = 0.48;
    }
    {
      k = 500;
      v = 0.57;
    }
    {
      k = 550;
      v = 0.66;
    }
    {
      k = 600;
      v = 0.75;
    }
    {
      k = 650;
      v = 0.825;
    }
    {
      k = 700;
      v = 0.90;
    }
    {
      k = 750;
      v = 0.95;
    }
    {
      k = 800;
      v = 1.00;
    }
    {
      k = 850;
      v = 0.975;
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
        lib.nameValuePair (toString p.k) hex
      ) paletteChromaKeys
    );

}
