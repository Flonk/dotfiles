{
  config,
  lib,
  ...
}:
let
  g = config.programs.gloxwald;
in
{
  config = lib.mkIf (g.starship.enable && config.programs.starship.enable) {
    programs.starship.settings.palettes.base16.accent = g.stylix.accent;
  };
}
