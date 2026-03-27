{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.desktop.vicinae.enable (
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

      (lib.mkIf config.skynet.module.desktop.hyprland.enable {
        wayland.windowManager.hyprland.settings = {
          bind = [
            "$mainMod, SPACE, exec, vicinae open"
            "MOD3, C, exec, xdg-open vicinae://extensions/florisdobber/claude/ask"
            "MOD3, period, exec, xdg-open vicinae://extensions/vicinae/core/search-emojis"
            "MOD3, B, exec, xdg-open vicinae://extensions/Gelei/bluetooth/devices"
          ];
        };
      })
    ]
  );
}
