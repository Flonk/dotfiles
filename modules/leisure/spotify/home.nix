{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.skynet.module.spotify.enable {
    home.packages = with pkgs; [ spotify ];
  };
}
