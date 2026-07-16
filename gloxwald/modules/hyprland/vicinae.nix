{
  pkgs,
  config,
  lib,
  ...
}:
{
  options.programs.gloxwald.vicinae.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Ship the vicinae launcher (requires the vicinae home-manager module to be imported)";
  };

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
