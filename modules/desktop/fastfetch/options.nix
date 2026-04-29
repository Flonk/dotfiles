{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.desktop.fastfetch.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
