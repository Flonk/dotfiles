{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.desktop.vicinae.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
