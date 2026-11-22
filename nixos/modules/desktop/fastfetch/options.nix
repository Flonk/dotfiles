{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.desktop.fastfetch.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
