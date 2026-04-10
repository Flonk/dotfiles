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
        default-timeout = 10000;
        layer = "overlay";
        max-visible = 3;
        padding = "10";
        width = 340;
        height = 300;

        "urgency=low" = {
          default-timeout = 4000;
        };

        "urgency=normal" = {
          default-timeout = 8000;
        };

        "urgency=high" = {
          default-timeout = 30000;
        };
      };

    };
  };
}
