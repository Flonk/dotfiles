{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.core.eventbus.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
