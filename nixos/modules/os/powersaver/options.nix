{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.os.powersaver.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
