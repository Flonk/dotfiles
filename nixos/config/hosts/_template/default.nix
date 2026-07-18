{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../../types
    ../common.nix
    ./__HOST__-hardware.nix
    ./__HOST__-hostconfig.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "__ARCH__";
  system.stateVersion = "__STATEVERSION__";
}
