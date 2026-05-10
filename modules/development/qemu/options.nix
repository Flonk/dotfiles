{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.development.qemu.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
