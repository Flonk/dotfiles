{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.development.obsidian.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
