{
  pkgs,
  config,
  lib,
  theme,
  ...
}:
{

  # mako notification daemon
  services.mako = {
    enable = true;
    settings = {
      actions = true;
      anchor = "top-right";
      border-radius = 0;
      border-size = 2;
      font = theme.font.ui.normal;
      default-timeout = 10000;
      layer = "overlay";
      max-visible = 3;
      padding = "10";
      width = 340;
      height = 300;
      border-color = theme.color.notifications.normal;
      background-color = theme.color.notifications.backgroundColor;

      "urgency=low" = {
        border-color = theme.color.notifications.low;
        text-color = theme.color.notifications.lowText;
      };

      "urgency=normal" = {
        border-color = theme.color.notifications.normal;
        text-color = theme.color.notifications.normalText;
      };

      "urgency=high" = {
        border-color = theme.color.notifications.urgent;
        text-color = theme.color.notifications.urgentText;
        default-timeout = 30000;
      };
    };

  };

}
