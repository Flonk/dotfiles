{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.core.git.enable = mkOption {
    type = types.bool;
    default = true;
  };
}
