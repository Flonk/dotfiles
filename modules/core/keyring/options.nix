{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.core.keyring.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
