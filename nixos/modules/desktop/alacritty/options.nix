{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.desktop.alacritty.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
