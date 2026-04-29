{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.leisure."obs-studio".enable = mkOption {
    type = types.bool;
    default = false;
  };
}
