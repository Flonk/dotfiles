{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.assorted.avahi.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
