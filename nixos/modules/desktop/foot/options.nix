{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.desktop.foot.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
