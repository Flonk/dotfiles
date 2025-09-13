{ lib, ... }:
rec {
  pi = 3.141592653589793;
  toRad = deg: deg * pi / 180.0;

  floatMod =
    a: b:
    let
      r = builtins.floor (a / b);
    in
    a - r * b;
}
