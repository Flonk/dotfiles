{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.assorted.nchat.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
