{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.core.bitwarden.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
