{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.assorted.avahi.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
