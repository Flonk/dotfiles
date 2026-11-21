{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.core.ssh = {
    enable = mkOption {
      type = types.bool;
      default = true;
    };
    knockScript = mkOption {
      type = types.nullOr types.path;
      default = null;
      internal = true;
    };
  };
}
