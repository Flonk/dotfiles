{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.t3os.module.core.bitwarden.enable {
    home.packages = [
      pkgs.bitwarden-cli
      pkgs.bitwarden-desktop
    ];
  };
}
