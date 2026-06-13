{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.desktop.hyprland.enable {
    home.packages = with pkgs; [
      hyprpicker
    ];

    wayland.windowManager.hyprland.extraConfig = ''
      hl.bind(mainMod .. " + C", hl.dsp.exec_cmd([[bash -lc 'color="$(hyprpicker -a)"; [ -n "$color" ] && notify-send "🎨 Color copied" "$color"']]))
    '';
  };
}
