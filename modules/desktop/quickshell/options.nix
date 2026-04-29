{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.desktop.quickshell.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
