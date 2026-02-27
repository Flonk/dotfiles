{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.skynet.module.home.antigravity {
    home.packages = [
      pkgs.google-antigravity
    ];
  };
}
