{
  config,
  lib,
  ...
}:
let
  s = config.lib.stylix.colors.withHashtag;
  accent = config.skynet.module.desktop.stylix.accent;
  accentDark = config.skynet.module.desktop.stylix.accentDark;
  borderColor = "rgba(${builtins.substring 1 6 accent}ff)";
  inactiveBorderColor = "rgba(${builtins.substring 1 6 s.base01}ff)";
in
{
  config = lib.mkIf config.skynet.module.desktop.hyprland.enable {
    wayland.windowManager.hyprland.settings = {
      general = {
        "col.active_border" = lib.mkForce borderColor;
        "col.inactive_border" = lib.mkForce inactiveBorderColor;
      };

      group = {
        "col.border_active" = lib.mkForce borderColor;
        "col.border_inactive" = lib.mkForce inactiveBorderColor;
        "col.border_locked_active" = lib.mkForce inactiveBorderColor;
        "col.border_locked_inactive" = lib.mkForce inactiveBorderColor;

        groupbar = {
          "col.active" = lib.mkForce borderColor;
          "col.locked_active" = lib.mkForce inactiveBorderColor;
          "col.inactive" = lib.mkForce "rgba(ffffff33)";
          "col.locked_inactive" = lib.mkForce "rgba(ffffff33)";
          text_color = lib.mkForce borderColor;
        };
      };

      decoration.shadow.color = lib.mkForce "rgba(00000022)";

      plugin.hy3.tabs = {
        "col.active" = borderColor;
        "col.active.border" = borderColor;
        "col.active.text" = inactiveBorderColor;

        "col.focused" = inactiveBorderColor;
        "col.focused.border" = inactiveBorderColor;
        "col.focused.text" = "rgba(${builtins.substring 1 6 accentDark}ff)";

        "col.inactive" = inactiveBorderColor;
        "col.inactive.border" = inactiveBorderColor;
        "col.inactive.text" = "rgba(${builtins.substring 1 6 accentDark}ff)";

        "col.urgent" = "rgba(${builtins.substring 1 6 s.base08}ff)";
        "col.urgent.border" = "rgba(${builtins.substring 1 6 s.base08}ff)";
        "col.urgent.text" = "rgba(${builtins.substring 1 6 s.base07}ff)";
      };
    };
  };
}
