{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.leisure.twitch = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    clientId = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Client ID of a public Twitch application (dev.twitch.tv/console), used for the device login.";
    };
  };
}
