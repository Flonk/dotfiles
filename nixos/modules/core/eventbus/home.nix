{
  pkgs,
  config,
  lib,
  ...
}:
let
  t3cron = pkgs.rustPlatform.buildRustPackage {
    pname = "t3cron";
    version = "0.1.0";
    src = ./t3cron;
    cargoLock.lockFile = ./t3cron/Cargo.lock;
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.sqlite ];
  };
  cfg = config.skynet.module.core.eventbus;
  registry = lib.importJSON ../../../.registry.json;
  mosquittoConf = pkgs.writeText "mosquitto.conf" ''
    listener 1883 127.0.0.1
    allow_anonymous true
    persistence true
    persistence_location ${config.home.homeDirectory}/.local/state/mosquitto/
  '';
  bridgeScript =
    name:
    let
      host = registry.${name};
      knock = config.skynet.module.core.ssh.knockScript;
      pub = "${pkgs.mosquitto}/bin/mosquitto_pub -h 127.0.0.1";
    in
    pkgs.writeShellScript "eventbus-bridge-${name}" ''
      seen=$(${pkgs.coreutils}/bin/mktemp)
      trap '${pkgs.coreutils}/bin/rm -f "$seen"' EXIT
      while true; do
        ${lib.optionalString ((host.knock or false) && knock != null) "${knock} ${host.ip} >/dev/null 2>&1 || true"}
        ${pkgs.openssh}/bin/ssh -o BatchMode=yes -o ConnectTimeout=15 -o ServerAliveInterval=20 -o ServerAliveCountMax=3 \
          ${host.user}@${host.ip} 'PATH="$HOME/.nix-profile/bin:$PATH" exec mosquitto_sub -h 127.0.0.1 -v -t "agent/#"' \
          | while IFS=' ' read -r topic payload; do
              ${pkgs.gnugrep}/bin/grep -qxF "$topic" "$seen" || echo "$topic" >> "$seen"
              if [ -n "$payload" ]; then ${pub} -r -t "$topic" -m "$payload"; else ${pub} -r -n -t "$topic"; fi
            done
        while read -r topic; do ${pub} -r -t "$topic" -m offline; done < "$seen"
        sleep 15
      done
    '';
  failWatch = pkgs.writeShellScript "t3bus-failwatch" ''
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gawk
        pkgs.jq
        pkgs.systemd
        t3cron
      ]
    }
    failed() {
      systemctl list-units --state=failed --plain --no-legend --no-pager | awk '{print "system:" $1}'
      systemctl --user list-units --state=failed --plain --no-legend --no-pager | awk '{print "user:" $1}'
    }
    declare -A seen
    for k in $(failed); do seen[$k]=1; done
    while true; do
      sleep 10
      unset now
      declare -A now
      for k in $(failed); do now[$k]=1; done
      for k in "''${!now[@]}"; do
        [ -n "''${seen[$k]:-}" ] && continue
        scope=''${k%%:*}
        unit=''${k#*:}
        if [ "$scope" = user ]; then line=$(journalctl --user -u "$unit" -n 1 -o cat --no-pager 2>/dev/null); else line=$(journalctl -u "$unit" -n 1 -o cat --no-pager 2>/dev/null); fi
        t3cron emit "systemd/''${unit%.*}/failed" error "$unit failed" --attention --source systemd \
          --data "$(jq -nc --arg detail "$line" --arg scope "$scope" '{detail: $detail, scope: $scope}')"
      done
      for k in "''${!seen[@]}"; do
        [ -n "''${now[$k]:-}" ] && continue
        unit=''${k#*:}
        t3cron emit "systemd/''${unit%.*}/recovered" info "$unit is no longer failed" --source systemd
      done
      unset seen
      declare -A seen
      for k in "''${!now[@]}"; do seen[$k]=1; done
    done
  '';
  notifyBridge = pkgs.writeShellScript "t3bus-notify-bridge" ''
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.jq
        pkgs.systemd
        t3cron
      ]
    }
    busctl --user monitor --json=short --match="type='method_call',interface='org.freedesktop.Notifications',member='Notify'" \
      | jq --unbuffered -c 'select(.member == "Notify") | .payload.data | {app: (.[0] // ""), summary: (.[3] // ""), body: (.[4] // ""), urgency: (.[6].urgency.data // 1)}' \
      | while read -r n; do
          app=$(jq -r '.app | if . == "" then "unknown" else . end' <<<"$n")
          slug=$(tr -c 'a-zA-Z0-9\n' '-' <<<"$app" | tr 'A-Z' 'a-z')
          summary=$(jq -r .summary <<<"$n")
          set -- --source "$app" --data "$(jq -c '{detail: (.body | split("\n")[0]), app: .app}' <<<"$n")"
          if [ "$(jq -r .urgency <<<"$n")" = 2 ]; then
            t3cron emit "notify/$slug" warn "$summary" --attention "$@"
          else
            t3cron emit "notify/$slug" info "$summary" "$@"
          fi
        done
  '';
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.mosquitto
      t3cron
    ]
    ++ lib.optional cfg.ui pkgs.mqtt-explorer;

    systemd.user.services = lib.mkMerge [
      (lib.mkIf cfg.userBroker {
        mosquitto = {
          Unit.Description = "mosquitto MQTT broker";
          Service = {
            ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${config.home.homeDirectory}/.local/state/mosquitto";
            ExecStart = "${pkgs.mosquitto}/bin/mosquitto -c ${mosquittoConf}";
            Restart = "always";
            RestartSec = "5s";
          };
          Install.WantedBy = [ "default.target" ];
        };
      })
      (lib.listToAttrs (
        map (name: {
          name = "eventbus-bridge-${name}";
          value = {
            Unit = {
              Description = "Mirror agent/# from ${name} onto the local bus";
              After = [ "network-online.target" ];
              Wants = [ "network-online.target" ];
            };
            Service = {
              ExecStart = bridgeScript name;
              Restart = "always";
              RestartSec = "15s";
            };
            Install.WantedBy = [ "default.target" ];
          };
        }) cfg.bridges
      ))
      {
        t3cron = {
          Unit.Description = "t3cron, cron jobs that publish onto the MQTT bus";
          Service = {
            ExecStart = "${t3cron}/bin/t3cron daemon";
            Restart = "always";
            RestartSec = "5s";
          };
          Install.WantedBy = [ "default.target" ];
        };
        t3bus-failwatch = {
          Unit.Description = "Emit failed systemd units onto the bus";
          Service = {
            ExecStart = "${failWatch}";
            Restart = "always";
            RestartSec = "10s";
          };
          Install.WantedBy = [ "default.target" ];
        };
      }
      (lib.mkIf cfg.ui {
        t3bus-notify-bridge = {
          Unit = {
            Description = "Mirror desktop notifications onto the bus";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = "${notifyBridge}";
            Restart = "always";
            RestartSec = "5s";
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      })
    ];

    skynet.cli.scripts = [
      {
        command = [ "cron" ];
        title = "Manage t3cron jobs on the bus";
        script = pkgs.writeShellScript "cron.sh" ''
          exec ${t3cron}/bin/t3cron "$@"
        '';
        usage = "List, add, remove, run and watch t3cron jobs: skynet cron [list|add <key> <schedule> <topic> [payload]|rm <key>|run <key>|watch]. Schedules are cron expressions or one-shots like 'in 10m' / 'at 18:00'.";
      }
      {
        command = [
          "bus"
          "watch"
        ];
        title = "Watch every event on the MQTT bus";
        script = pkgs.writeShellScript "bus-watch.sh" ''
          exec ${pkgs.mosquitto}/bin/mosquitto_sub -h 127.0.0.1 -v -t '#' "$@"
        '';
        usage = "Prints every message on the local mosquitto bus with its topic.";
      }
      {
        command = [ "screenshot" ];
        title = "Screenshot the active monitor and announce it on the bus";
        script = pkgs.writeShellScript "screenshot.sh" ''
          set -euo pipefail
          dir="''${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
          mkdir -p "$dir"
          file="$dir/$(date +%Y-%m-%d-%H%M%S)_skynet.png"
          ${t3cron}/bin/t3cron emit screenshot/taken info "somebody has taken a screenshot" --source skynet --data "$(${pkgs.jq}/bin/jq -nc --arg path "$file" '{path: $path, detail: ($path | split("/") | last)}')"
          ${pkgs.hyprshot}/bin/hyprshot -m output -m active -r png > "$file" || true
          [ -s "$file" ] || { echo "screenshot failed" >&2; exit 1; }
          echo "$file"
        '';
        usage = "Emits screenshot/taken on the bus (fire and forget) and saves a screenshot of the active monitor to ~/Pictures/Screenshots and prints the path.";
      }
      {
        command = [
          "bus"
          "emit"
        ];
        title = "Emit a schema event onto the bus";
        script = pkgs.writeShellScript "bus-emit.sh" ''
          exec ${t3cron}/bin/t3cron emit "$@"
        '';
        usage = "skynet bus emit <topic> <level> <description> [--attention] [--data <json>] [--source <name>]. Levels: error warn info http verbose debug silly. See nixos/modules/core/eventbus/event.schema.json.";
      }
    ];
  };
}
