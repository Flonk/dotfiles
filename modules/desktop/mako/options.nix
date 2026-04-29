{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.desktop.mako.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
