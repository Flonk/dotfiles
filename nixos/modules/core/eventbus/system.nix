{
  config,
  lib,
  pkgs,
  ...
}:
let
  nmEvents = pkgs.writeShellScript "t3bus-networkmanager" ''
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.jq
        pkgs.mosquitto
      ]
    }
    iface=$1
    action=$2
    case "$iface" in lo | veth* | docker* | br-* | virbr*) exit 0 ;; esac
    name="''${CONNECTION_ID:-$iface}"
    case "$action" in
      up) desc="$name connected." ;;
      down) desc="$name disconnected." ;;
      vpn-up) desc="VPN $name connected." ;;
      vpn-down) desc="VPN $name disconnected." ;;
      *) exit 0 ;;
    esac
    body=$(jq -nc --arg ts "$(date +%Y-%m-%dT%H:%M:%S.%3N%:z)" --arg desc "$desc" --arg iface "$iface" --arg action "$action" \
      '{timestamp: $ts, source: "networkmanager", level: "info", attention: false, description: $desc, data: {detail: $iface, action: $action}}')
    mosquitto_pub -h 127.0.0.1 -q 1 -t "network/$iface/$action" -m "$body" 2>/dev/null || true
  '';
in
{
  config = lib.mkIf config.t3os.module.core.eventbus.enable {
    services.mosquitto = {
      enable = true;
      listeners = [
        {
          address = "127.0.0.1";
          port = 1883;
          omitPasswordAuth = true;
          acl = [ "topic readwrite #" ];
          settings.allow_anonymous = true;
        }
      ];
    };

    networking.networkmanager.dispatcherScripts = [
      {
        source = nmEvents;
        type = "basic";
      }
    ];
  };
}
