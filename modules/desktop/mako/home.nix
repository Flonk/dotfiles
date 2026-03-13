{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.desktop.mako.enable {
    # mako notification daemon
    services.mako = {
      enable = true;
      settings = {
        actions = true;
        anchor = "top-right";
        border-radius = 0;
        border-size = 2;
        font = config.skynet.theme.font.ui.normal;
        default-timeout = 10000;
        layer = "overlay";
        max-visible = 3;
        padding = "10";
        width = 340;
        height = 300;
        border-color = config.skynet.theme.color.wm800;
        background-color = config.skynet.theme.color.app150;

        "urgency=low" = {
          border-color = config.skynet.theme.color.app600;
          text-color = config.skynet.theme.color.app600;
        };

        "urgency=normal" = {
          border-color = config.skynet.theme.color.wm800;
          text-color = config.skynet.theme.color.text;
        };

        "urgency=high" = {
          border-color = config.skynet.theme.color.error600;
          text-color = config.skynet.theme.color.text;
          default-timeout = 30000;
        };
      };

    };
  };
}
