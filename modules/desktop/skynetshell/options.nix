{ lib, ... }:
{
  options.skynet.module.desktop.skynetshell.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };
}
