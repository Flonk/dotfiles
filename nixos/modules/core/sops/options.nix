{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.core.sops.enable = mkOption {
    type = types.bool;
    default = true;
  };
}
