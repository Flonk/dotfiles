{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.desktop."google-chrome".enable = mkOption {
    type = types.bool;
    default = false;
  };
}
