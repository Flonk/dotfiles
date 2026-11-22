{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.desktop.csvlens.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
