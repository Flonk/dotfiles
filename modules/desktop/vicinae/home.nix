{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.vicinae.enable (
    lib.mkMerge [
      {
        services.vicinae = {
          enable = true;

          package = pkgs.vicinae;

          systemd = {
            enable = true;
            autoStart = true;
            target = "graphical-session.target";
          };
        };
      }

      (lib.mkIf config.skynet.module.hyprland.enable {
        wayland.windowManager.hyprland.settings = {
          bind = [
            "$mainMod, SPACE, exec, vicinae open"
            "MOD3, C, exec, xdg-open vicinae://extensions/florisdobber/claude/ask"
          ];
        };
      })
    ]
  );
}
