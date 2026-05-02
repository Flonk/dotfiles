{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.desktop.qutebrowser.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
