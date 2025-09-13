{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.hostconfig = {
    primaryMonitor = {
      width = mkOption {
        type = types.int;
        default = 1920;
      };
      height = mkOption {
        type = types.int;
        default = 1080;
      };
      hz = mkOption {
        type = types.int;
        default = 60;
      };
    };
  };
}
