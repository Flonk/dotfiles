{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.core.eventbus = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    calendar = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
      calendars = mkOption {
        type = types.listOf types.str;
        default = [ "primary" ];
      };
      soonMinutes = mkOption {
        type = types.int;
        default = 10;
      };
    };
  };
}
