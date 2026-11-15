{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.desktop.mazama.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
