{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.leisure.lutris.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
