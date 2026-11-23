{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.t3os.module.core.eventbus;
  host = config.t3os.whoami.host;
  registry = lib.importJSON ../../../.registry.json;
  peers = lib.filter (h: h != host) (map (n: lib.last (lib.splitString "-" n)) (lib.attrNames registry));
  forward = pkgs.writeShellApplication {
    name = "t3bus-ntfy-forward";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
      pkgs.mosquitto
    ];
    runtimeEnv = {
      T3BUS_HOST = host;
      T3BUS_PEERS = lib.concatStringsSep " " peers;
    };
    text = builtins.readFile ./ntfy-forward.sh;
  };
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
  config = lib.mkMerge [
  (lib.mkIf cfg.enable {
    services.mosquitto = {
      enable = true;
      settings.queue_qos0_messages = true;
      bridges = lib.mkIf (cfg.upstream != null) {
        upstream = {
          addresses = [
            {
              address = "127.0.0.1";
              port = 18830;
            }
          ];
          topics = [ ''# out 1 "" ${host}/'' ];
          settings = {
            cleansession = false;
            local_clientid = "${host}-bridge-local";
            remote_clientid = "${host}-bridge";
            restart_timeout = "5 60";
            try_private = true;
          };
        };
      };
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
  })
  (lib.mkIf cfg.push.enable {
    sops.secrets.ntfy-env.sopsFile = ./secrets/ntfy.json;
    sops.secrets.ntfy-token.sopsFile = ./secrets/ntfy.json;

    services.ntfy-sh = {
      enable = true;
      environmentFile = config.sops.secrets.ntfy-env.path;
      settings = {
        base-url = "https://${cfg.push.domain}:${toString cfg.push.port}";
        listen-http = "127.0.0.1:2586";
        behind-proxy = true;
        auth-default-access = "deny-all";
        enable-signup = false;
        web-root = "disable";
        visitor-request-limit-exempt-hosts = "127.0.0.1";
      };
    };

    services.caddy = {
      enable = true;
      virtualHosts."${cfg.push.domain}:${toString cfg.push.port}".extraConfig = ''
        reverse_proxy 127.0.0.1:2586
      '';
    };

    networking.firewall.allowedTCPPorts = [
      80
      cfg.push.port
    ];

    systemd.services.t3bus-ntfy-forward = {
      description = "Forward every bus event to ntfy";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "ntfy-sh.service"
      ];
      wants = [ "ntfy-sh.service" ];
      serviceConfig = {
        ExecStart = lib.getExe forward;
        DynamicUser = true;
        LoadCredential = "token:${config.sops.secrets.ntfy-token.path}";
        Restart = "always";
        RestartSec = "10s";
      };
    };
  })
  ];
}
