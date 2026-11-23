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
    upstream = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Registry host the local broker forwards every topic to, prefixed with the local host name, through an ssh tunnel on 127.0.0.1:18830.";
    };
    push = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Run ntfy behind caddy and forward every bus event to it.";
      };
      domain = mkOption {
        type = types.str;
        default = "ntfy.t3.at";
      };
      port = mkOption {
        type = types.port;
        default = 8443;
      };
      rules = mkOption {
        type = types.attrsOf (types.either (types.enum [ "drop" ]) (types.ints.between 1 5));
        default = { };
        example = {
          "+/display/#" = "drop";
          "+/agent/+/waiting" = 5;
        };
        description = "MQTT patterns matched against <host>/<topic>, mapped to a fixed ntfy priority or \"drop\". The longest matching pattern wins; unmatched events keep the level-based priority.";
      };
    };
  };
}
