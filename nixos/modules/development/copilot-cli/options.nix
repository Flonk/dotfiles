{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.development."copilot-cli".enable = mkOption {
    type = types.bool;
    default = false;
  };
}
