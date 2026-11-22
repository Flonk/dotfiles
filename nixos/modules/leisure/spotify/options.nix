{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.leisure.spotify.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
