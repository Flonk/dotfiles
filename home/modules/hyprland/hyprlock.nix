{
  pkgs,
  config,
  lib,
  theme,
  ...
}: {
  
  programs.hyprlock = {
    enable = true;
  };
  
}
