{
  pkgs,
  config,
  lib,
  ...
}:
let
  zeroclawPkg = pkgs.callPackage ./package.nix { };
in
{
  config = lib.mkIf config.skynet.module.zeroclaw.enable {
    home.packages = [
      zeroclawPkg
    ];
  };
}
