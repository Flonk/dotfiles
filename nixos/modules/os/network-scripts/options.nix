{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.os."network-scripts".enable = mkOption {
    type = types.bool;
    default = false;
  };
}
