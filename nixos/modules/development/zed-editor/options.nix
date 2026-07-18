{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.development."zed-editor".enable = mkOption {
    type = types.bool;
    default = false;
  };
}
