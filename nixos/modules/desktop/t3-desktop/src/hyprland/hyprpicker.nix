{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.programs.t3-desktop.hyprland.enable {
    home.packages = with pkgs; [
      hyprpicker
    ];

    wayland.windowManager.hyprland.extraConfig = ''
      hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("t3os screen color-pick -c -n"))
    '';
  };
}
