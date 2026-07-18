{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.assorted.jiratui.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
