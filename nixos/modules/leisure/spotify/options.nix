{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.leisure.spotify.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
