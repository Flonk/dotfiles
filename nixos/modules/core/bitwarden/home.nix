{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.skynet.module.core.bitwarden.enable {
    home.packages = [
      pkgs.bitwarden-cli
      pkgs.bitwarden-desktop
    ];
  };
}
