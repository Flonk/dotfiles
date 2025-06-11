{
  pkgs,
  config,
  lib,
  theme,
  ...
}: {
  
  # mako notification daemon
  services.mako = {
    enable = true;
    settings = {
      actions = true;
      anchor = "top-right";
      border-radius = 0;
      border-size = 2;
      font = theme.fonts.ui.small;
      default-timeout = 10000;
      layer = "overlay";
      max-visible = 3;
      padding = "10";
      width = 340;
      height = 300;
      border-color = theme.colors.notifications.normal;
      background-color = theme.colors.notifications.backgroundColor;

      "urgency=low" = {
        border-color = theme.colors.notifications.low;
        text-color = theme.colors.notifications.lowText;
      };

      "urgency=normal" = {
        border-color = theme.colors.notifications.normal;
        text-color = theme.colors.notifications.normalText;
      };

      "urgency=high" = {
        border-color = theme.colors.notifications.urgent;
        text-color = theme.colors.notifications.urgentText;
        default-timeout = 0;
      };
    };

  };
  
}
