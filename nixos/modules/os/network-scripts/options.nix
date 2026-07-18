{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.os."network-scripts".enable = mkOption {
    type = types.bool;
    default = false;
  };
}
