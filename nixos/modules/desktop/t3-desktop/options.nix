{ lib, ... }:
{
  options.skynet.module.desktop.t3-desktop.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };
}
