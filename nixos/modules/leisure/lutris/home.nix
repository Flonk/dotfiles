{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.leisure.lutris.enable {
    home.packages = with pkgs; [
      lutris
    ];
  };
}
