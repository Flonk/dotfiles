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
      font.normal.family = config.theme.fontFamily.mono;
      colors.primary.background = config.theme.color.app150;
    };
  };

}
