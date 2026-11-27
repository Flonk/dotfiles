{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.ai."claude-code" = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };
}
