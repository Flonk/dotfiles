{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.development."claude-code".enable = mkOption {
    type = types.bool;
    default = false;
  };
}
