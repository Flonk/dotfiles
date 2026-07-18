{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.desktop.csvlens.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
