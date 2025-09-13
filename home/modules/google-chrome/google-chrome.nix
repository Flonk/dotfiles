{
  pkgs,
  config,
  lib,
  ...
}:
{

  home.packages = lib.mkBefore [
    pkgs.google-chrome
  ];

}
