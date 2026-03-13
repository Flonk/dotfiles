{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.hyprland.enable {
    home.packages = with pkgs; [
      hyprpicker
    ];

    wayland.windowManager.hyprland.settings.bind = [
      "$mainMod, C, exec, hyprpicker -a"
    ];
  };
}
