{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.desktop."vicinae-askpass" = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };

    timeoutSeconds = mkOption {
      type = types.int;
      default = 120;
    };
  };
}
