{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.skynet.module.home.spotify {
    home.packages = with pkgs; [ spotify ];
  };
}
