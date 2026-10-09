{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.leisure.photocraft.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
