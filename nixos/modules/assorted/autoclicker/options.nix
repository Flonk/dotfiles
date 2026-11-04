{ lib, ... }:
{
  options.skynet.module.assorted.autoclicker.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };
}
