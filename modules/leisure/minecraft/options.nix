{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.leisure.minecraft.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
