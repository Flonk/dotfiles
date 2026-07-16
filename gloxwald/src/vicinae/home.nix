{
  pkgs,
  config,
  lib,
  ...
}:
{
  config =
    lib.mkIf (config.programs.gloxwald.hyprland.enable && config.programs.gloxwald.vicinae.enable)
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

        wayland.windowManager.hyprland.settings.layer_rule = [
          {
            match.namespace = "vicinae";
            dim_around = true;
          }
        ];

        wayland.windowManager.hyprland.extraConfig = ''
          hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("vicinae open"))
          hl.bind("MOD3 + period", hl.dsp.exec_cmd("xdg-open vicinae://launch/core/search-emojis"))
        '';
      };
}
