{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.desktop.hyprland.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
