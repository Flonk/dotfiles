{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.skynet.module.leisure.spotify.enable {
    home.packages = with pkgs; [ spotify ];
  };
}
