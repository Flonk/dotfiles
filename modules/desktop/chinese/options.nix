{ lib, ... }:
{
  options.skynet.module.desktop.chinese.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };
}
