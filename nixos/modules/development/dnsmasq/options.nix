{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.development.dnsmasq.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
