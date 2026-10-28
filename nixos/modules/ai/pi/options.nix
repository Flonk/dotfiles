{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.ai.pi.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
