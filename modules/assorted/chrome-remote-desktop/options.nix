{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.assorted."chrome-remote-desktop".enable = mkOption {
    type = types.bool;
    default = false;
  };
}
