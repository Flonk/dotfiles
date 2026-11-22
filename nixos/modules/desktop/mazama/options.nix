{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.desktop.mazama.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
