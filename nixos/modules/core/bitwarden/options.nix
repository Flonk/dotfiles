{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.core.bitwarden.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
