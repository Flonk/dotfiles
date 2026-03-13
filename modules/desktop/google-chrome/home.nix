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

  config = lib.mkIf config.skynet.module.desktop."google-chrome".enable {
    home.packages = lib.mkBefore [
      pkgs.google-chrome
    ];
  };
}
