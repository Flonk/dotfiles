{
  config,
  lib,
  pkgs,
  ...
}:
let
  g = config.programs.gloxwald;
  font = config.stylix.fonts.monospace.package;
  mark = pkgs.runCommand "gloxwald-t3-mark.png" {
    nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.pillow ])) ];
  } ''
    python3 -I ${../../dev/t3-mark.py} '${g.stylix.accent}' "$(find ${font} -name '*NerdFont-Bold.ttf' -o -name '*Mono-Bold.ttf' | sort | head -1)" $out
  '';
in
{
  config = lib.mkIf (g.fastfetch.enable && config.programs.fastfetch.enable) {
    programs.fastfetch.settings.logo.source = lib.mkForce "${mark}";
  };
}
