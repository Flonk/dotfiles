{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
{
  config = lib.mkIf config.skynet.module.desktop.mazama.enable {
    home.packages = [ inputs.mazama.packages.${pkgs.stdenv.hostPlatform.system}.default ];
  };
}
