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
  inactiveBorderColor = "rgba(000000ff)";
in
{
  config = lib.mkIf config.programs.gloxwald.hyprland.enable {
    wayland.windowManager.hyprland.settings.config = {
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

      plugin.hy3.tabs.colors = {
        active = borderColor;
        active_border = borderColor;
        active_text = inactiveBorderColor;

        focused = inactiveBorderColor;
        focused_border = inactiveBorderColor;
        focused_text = "rgba(${builtins.substring 1 6 accentDark}ff)";

        inactive = inactiveBorderColor;
        inactive_border = inactiveBorderColor;
        inactive_text = "rgba(${builtins.substring 1 6 accentDark}ff)";

        urgent = "rgba(${builtins.substring 1 6 s.base08}ff)";
        urgent_border = "rgba(${builtins.substring 1 6 s.base08}ff)";
        urgent_text = "rgba(${builtins.substring 1 6 s.base07}ff)";
      };
    };
  };
}
