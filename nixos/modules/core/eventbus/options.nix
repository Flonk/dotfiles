{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.core.eventbus = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    ui = mkOption {
      type = types.bool;
      default = true;
    };
    userBroker = mkOption {
      type = types.bool;
      default = false;
    };
    bridges = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Registry hosts whose agent/# topics are mirrored onto the local bus over ssh.";
    };
  };
}
