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

  config = lib.mkIf config.skynet.module.google-chrome.enable {
    home.packages = lib.mkBefore [
      pkgs.google-chrome
    ];
  };
}
