{
  pkgs,
  config,
  lib,
  theme,
  ...
}:
{

  programs.alacritty = {
    enable = true;
    settings = {
      font.size = theme.fontSize.small;
      font.normal.family = theme.fontFamily.mono;
    };
  };

}
