{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.core.sops.enable = mkOption {
    type = types.bool;
    default = true;
  };
}
