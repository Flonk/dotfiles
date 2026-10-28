{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.ai."copilot-cli".enable = mkOption {
    type = types.bool;
    default = false;
  };
}
