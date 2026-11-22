{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.leisure."obs-studio".enable = mkOption {
    type = types.bool;
    default = false;
  };
}
