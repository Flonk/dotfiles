{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.core.keyring.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
