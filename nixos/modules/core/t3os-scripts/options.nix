{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.core."t3os-scripts".enable = mkOption {
    type = types.bool;
    default = true;
  };
}
