{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.t3os.module.desktop.stylix;
in
{
  config = lib.mkMerge [
    {
      programs.t3-desktop.stylix.enable = cfg.enable;
      stylix = {
        enable = lib.mkDefault true;
        base16Scheme = lib.mkDefault "${pkgs.base16-schemes}/share/themes/${cfg.scheme}.yaml";
        targets.rofi.enable = false;
      };
    }
    (lib.mkIf cfg.enable {
      programs.t3-desktop.stylix = {
        scheme = cfg.scheme;
        accent = cfg.accent;
        ground = cfg.ground;
      };
    })
    (lib.mkIf (cfg.wallpaper != null) {
      programs.t3-desktop.wallpaper = cfg.wallpaper;
    })
  ];
}
