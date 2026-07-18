{ lib, ... }:
{
  options.skynet.module.desktop.gloxwald.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };
}
