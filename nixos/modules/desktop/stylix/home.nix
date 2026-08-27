{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.skynet.module.desktop.stylix;
in
{
  config = lib.mkMerge [
    {
      programs.gloxwald.stylix.enable = cfg.enable;
      stylix.base16Scheme = lib.mkDefault "${pkgs.base16-schemes}/share/themes/${cfg.scheme}.yaml";
    }
    (lib.mkIf cfg.enable {
      programs.gloxwald.stylix = {
        scheme = cfg.scheme;
        accent = cfg.accent;
        accentDark = cfg.accentDark;
      };
    })
    (lib.mkIf (cfg.wallpaper != null) {
      programs.gloxwald.wallpaper = cfg.wallpaper;
    })
  ];
}
