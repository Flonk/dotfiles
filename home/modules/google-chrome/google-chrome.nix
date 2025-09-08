{
  pkgs,
  config,
  lib,
  theme,
  ...
}:
{

  home.packages = lib.mkBefore [
    pkgs.google-chrome
  ];

}
