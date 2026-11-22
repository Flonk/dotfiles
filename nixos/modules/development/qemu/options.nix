{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.development.qemu.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
