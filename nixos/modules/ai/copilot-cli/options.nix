{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.ai."copilot-cli".enable = mkOption {
    type = types.bool;
    default = false;
  };
}
