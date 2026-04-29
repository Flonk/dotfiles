{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.desktop.waybar.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
