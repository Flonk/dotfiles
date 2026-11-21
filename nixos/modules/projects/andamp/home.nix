{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.skynet.module.projects.andamp;
  mutexWatch = pkgs.writeShellScript "andamp-mutex-watch" ''
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnugrep
        pkgs.iproute2
        pkgs.procps
        pkgs.jq
        pkgs.mosquitto
      ]
    }
    pub() { mosquitto_pub -h 127.0.0.1 -q 1 "$@" 2>/dev/null; }
    event() {
      pub -t "mutex/$1/event" -m "$(jq -nc --arg ts "$(date +%Y-%m-%dT%H:%M:%S.%3N%:z)" --arg desc "$2" --arg state "$3" \
        '{timestamp: $ts, source: "andamp-mutex-watch", level: "info", attention: false, description: $desc, data: {state: $state}}')"
    }
    declare -A last
    report() {
      local name=$1 state=$2 waiting=$3 desc=$4
      [ "''${last[$name]:-}" = "$state $waiting" ] && return
      [ -n "''${last[$name]:-}" ] && event "$name" "$desc" "$state"
      last[$name]="$state $waiting"
      pub -r -t "mutex/$name/state" -m "$state"
      pub -r -t "mutex/$name/waiting" -m "$waiting"
    }
    while true; do
      d="''${XDG_RUNTIME_DIR:-/tmp}/crdp"
      crdp=free
      if [ -e "$d/queue.lock" ] && [ $(( $(date +%s) - $(stat -c %Y "$d/queue.lock") )) -lt 10 ]; then crdp=busy; fi
      if find "$d" -maxdepth 1 -regex '.*/transaction-[0-9a-f]+' 2>/dev/null | grep -q .; then crdp=held; fi
      waiting=$(find "$d/queue" -type f -newermt "-10 seconds" 2>/dev/null | wc -l)
      case $crdp in
        free) what="crdp is free" ;;
        busy) what="crdp is running a command" ;;
        held) what="a crdp transaction holds the screen" ;;
      esac
      [ "$waiting" -gt 0 ] && what="$what, $waiting waiting"
      report crdp "$crdp" "$waiting" "$what"
      if ip link show tun0 >/dev/null 2>&1 && pgrep -x openconnect >/dev/null; then
        report vpn3it held 0 "3it vpn connected"
      else
        report vpn3it free 0 "3it vpn disconnected"
      fi
      sleep 2
    done
  '';
in
{
  imports = [
    ./CEFKM/home.nix
    ./CEIFRS/home.nix
    ./modules/vpn3it/home.nix
  ];

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable || cfg.doubletunnel) {
      sops.secrets.andamp-vpn = {
        format = "binary";
        sopsFile = ./secrets/andamp-vpn.ovpn;
      };

      sops.secrets.andamp-vpn-user = {
        sopsFile = ./secrets/andamp-vpn-auth.json;
      };

      sops.secrets.andamp-vpn-pass = {
        sopsFile = ./secrets/andamp-vpn-auth.json;
      };
    })
    (lib.mkIf cfg.enable {
      systemd.user.services.andamp-mutex-watch = {
        Unit.Description = "Publish crdp and 3it vpn mutex states onto the bus";
        Service = {
          ExecStart = "${mutexWatch}";
          Restart = "always";
          RestartSec = "5s";
        };
        Install.WantedBy = [ "default.target" ];
      };

      systemd.user.services.import-andamp-vpn = {
        Unit = {
          Description = "Import andamp-vpn profile to NetworkManager (idempotent)";
          After = [
            "default.target"
            "sops-nix.service"
          ];
          ConditionPathExists = [
            "${config.sops.secrets.andamp-vpn.path}"
            "${config.sops.secrets.andamp-vpn-user.path}"
            "${config.sops.secrets.andamp-vpn-pass.path}"
          ];
        };
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = (
            pkgs.writeShellScript "import-andamp-vpn" ''
              set -euo pipefail
              NAME="andamp-vpn"
              NMCLI="${pkgs.networkmanager}/bin/nmcli"
              if $NMCLI -t -f NAME con show | ${pkgs.gnugrep}/bin/grep -Fxq "$NAME"; then
                echo "$NAME already present; skipping import."
              else
                echo "Importing $NAME from ${config.sops.secrets.andamp-vpn.path}"
                $NMCLI connection import type openvpn file "${config.sops.secrets.andamp-vpn.path}"
              fi
              $NMCLI connection modify "$NAME" \
                +vpn.data "username=$(cat "${config.sops.secrets.andamp-vpn-user.path}")" \
                +vpn.data "password-flags=0" \
                vpn.secrets "password=$(cat "${config.sops.secrets.andamp-vpn-pass.path}")"
            ''
          );
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    })
  ];
}
