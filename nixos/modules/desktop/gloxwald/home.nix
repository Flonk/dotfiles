{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.desktop.gloxwald.enable {
    programs.gloxwald.quickshell.enable = true;
    programs.gloxwald.hyprland.enable = true;
  };
}
