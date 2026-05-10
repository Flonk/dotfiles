{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.desktop."google-chrome".enable = mkOption {
    type = types.bool;
    default = false;
  };
}
