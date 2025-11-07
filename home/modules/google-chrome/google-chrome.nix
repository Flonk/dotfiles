{
  pkgs,
  config,
  lib,
  ...
}:
{
  imports = [
    ./file-viewer.nix
  ];

  home.packages = lib.mkBefore [
    pkgs.google-chrome
  ];

}
