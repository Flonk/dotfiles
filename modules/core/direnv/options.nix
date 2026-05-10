{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.core.direnv.enable = mkOption {
    type = types.bool;
    default = true;
  };
}
