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

  config = lib.mkIf config.skynet.module.home.google-chrome {
    home.packages = lib.mkBefore [
      pkgs.google-chrome
    ];
  };
}
