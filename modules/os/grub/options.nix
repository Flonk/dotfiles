{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.os.grub.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
