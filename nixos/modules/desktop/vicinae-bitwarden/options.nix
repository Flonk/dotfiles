{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.desktop."vicinae-bitwarden".enable = mkOption {
    type = types.bool;
    default = false;
  };
}
