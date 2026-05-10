{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.host = {
    adminUser = mkOption {
      type = types.nullOr types.str;
      default = null;
    };

    motd = {
      command = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Shell command to run as MOTD in interactive zsh sessions";
      };
    };

    ssh = {
      authorizedKeys = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
    };

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
