{ lib, ... }:
{
  options.skynet.module.desktop.i18n.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };
}
