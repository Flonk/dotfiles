{
  config,
  lib,
  ...
}:
let
  s = config.lib.stylix.colors.withHashtag;
  accent = config.programs.gloxwald.stylix.accent;
  darken = hex: f: "#" + lib.concatMapStrings (i: lib.fixedWidthString 2 "0" (lib.toLower (lib.toHexString (builtins.floor (lib.fromHexString (builtins.substring i 2 (lib.removePrefix "#" hex)) * f))))) [ 0 2 4 ];
  borderColor = "rgba(${builtins.substring 1 6 accent}ff)";
  inactiveBorderColor = "rgba(000000ff)";
  rgba = hex: "rgba(${builtins.substring 1 6 hex}ff)";
  tabInactive = rgba (darken accent 0.14);
  tabInactiveText = rgba (darken accent 0.78);
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

        focused = tabInactive;
        focused_border = tabInactive;
        focused_text = tabInactiveText;

        inactive = tabInactive;
        inactive_border = tabInactive;
        inactive_text = tabInactiveText;

        urgent = "rgba(${builtins.substring 1 6 s.base08}ff)";
        urgent_border = "rgba(${builtins.substring 1 6 s.base08}ff)";
        urgent_text = "rgba(${builtins.substring 1 6 s.base07}ff)";
      };
    };
  };
}
