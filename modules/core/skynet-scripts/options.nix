{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.core."skynet-scripts".enable = mkOption {
    type = types.bool;
    default = true;
  };
}
