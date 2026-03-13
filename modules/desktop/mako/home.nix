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
        border-color = config.skynet.theme.color.wm800.hex;
        background-color = config.skynet.theme.color.app150.hex;

        "urgency=low" = {
          border-color = config.skynet.theme.color.app600.hex;
          text-color = config.skynet.theme.color.app600.hex;
          default-timeout = 4000;
        };

        "urgency=normal" = {
          border-color = config.skynet.theme.color.wm800.hex;
          text-color = config.skynet.theme.color.text.hex;
          default-timeout = 8000;
        };

        "urgency=high" = {
          border-color = config.skynet.theme.color.error600.hex;
          text-color = config.skynet.theme.color.text.hex;
          default-timeout = 30000;
        };
      };

    };
  };
}
