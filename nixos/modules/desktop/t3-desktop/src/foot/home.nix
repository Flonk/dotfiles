{
  config,
  lib,
  pkgs,
  ...
}:
let
  g = config.programs.t3-desktop;
  t3Pkgs = import ../../packages.nix {
    inherit pkgs;
    accent = g.stylix.accent;
    ground = g.stylix.ground;
  };
  palette = builtins.fromJSON (builtins.readFile "${t3Pkgs.chrome}/palette.json");
in
{
  config = lib.mkIf (g.foot.enable && config.programs.foot.enable) {
    programs.foot.settings = lib.genAttrs [ "colors-dark" "colors-light" ] (_: {
      background = lib.mkForce (lib.removePrefix "#" palette.ground);
      alpha = lib.mkForce g.foot.alpha;
    });
  };
}
