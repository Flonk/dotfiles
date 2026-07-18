{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.whoami = {
    host = mkOption {
      type = types.str;
      description = "The hostname of this machine";
    };

    user = mkOption {
      type = types.str;
      description = "The username for this configuration";
    };

    installation = mkOption {
      type = types.str;
      description = "The installation identifier (e.g. flo-chonkler)";
    };
  };
}
