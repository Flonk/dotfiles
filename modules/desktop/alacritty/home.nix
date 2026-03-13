{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.desktop.alacritty.enable {
    programs.alacritty = {
      enable = true;
      settings = {
        font.size = config.skynet.theme.fontSize.small;
        font.normal.family = config.skynet.theme.fontFamily.monoNf;
        colors.primary.background = config.skynet.theme.color.app150.hex;

        keyboard = {
          bindings = [
            # Ctrl+Enter → send CSI u sequence
            {
              key = "Enter";
              mods = "Control";
              chars = "\\u001b";
            }
          ];
        };
      };
    };
  };
}
