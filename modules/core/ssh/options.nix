{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.core.ssh.enable = mkOption {
    type = types.bool;
    default = true;
  };
}
