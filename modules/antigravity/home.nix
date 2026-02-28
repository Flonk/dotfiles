{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.skynet.module.antigravity.enable {
    home.packages = [
      pkgs.google-antigravity
    ];
  };
}
