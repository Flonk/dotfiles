{
  pkgs,
  config,
  lib,
  ...
}:
{

  programs.alacritty = {
    enable = true;
    settings = {
      font.size = config.theme.fontSize.small;
      font.normal.family = config.theme.fontFamily.monoNf;
      colors.primary.background = config.theme.color.app150;

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

}
