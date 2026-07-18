{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.development.dnsmasq.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
