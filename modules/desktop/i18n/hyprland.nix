{
  config,
  lib,
  ...
}:
let
  cfg = config.skynet.module.desktop.i18n;
in
{
  config = lib.mkIf (cfg.enable && config.skynet.module.desktop.hyprland.enable) {
    wayland.windowManager.hyprland.extraConfig = ''
      hl.bind("MOD3 + I", hl.dsp.exec_cmd("skynet-i18n cycle"))
    '';
  };
}
