{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.desktop.vicinae.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
