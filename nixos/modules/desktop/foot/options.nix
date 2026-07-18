{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.desktop.foot.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
