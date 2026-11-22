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
  cfg = config.t3os.module.core.eventbus;
  screenshot = pkgs.writeShellApplication {
    name = "t3os-screenshot";
    runtimeInputs = [
      t3cron
      pkgs.hyprshot
      pkgs.jq
      pkgs.wl-clipboard
      pkgs.libnotify
      pkgs.tesseract
      pkgs.coreutils
    ];
    text = builtins.readFile ./screenshot.sh;
  };
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
      knock = config.t3os.module.core.ssh.knockScript;
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

    t3os.cli.scripts = [
      {
        command = [ "cron" ];
        title = "Manage t3cron jobs on the bus";
        script = pkgs.writeShellScript "cron.sh" ''
          exec ${t3cron}/bin/t3cron "$@"
        '';
        usage = "List, add, remove, run and watch t3cron jobs: t3os cron [list|add <key> <schedule> <topic> [payload]|rm <key>|run <key>|watch]. Schedules are cron expressions or one-shots like 'in 10m' / 'at 18:00'.";
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
    ]
    ++ map
      (s: {
        command = [
          "screen"
          "shot"
        ]
        ++ lib.optional (s.mode != "monitor") s.mode;
        inherit (s) title;
        usage = s.usage + " Add -c to copy it to the clipboard and -n for a desktop notification.";
        script = pkgs.writeShellScript "screenshot-${s.mode}.sh" ''
          exec ${screenshot}/bin/t3os-screenshot ${s.mode} "$@"
        '';
      })
      [
        {
          mode = "monitor";
          title = "Screenshot a monitor and announce it on the bus";
          usage = "Saves the active monitor, or the one named as an argument (e.g. `t3os screen shot DP-2`), to ~/Pictures/Screenshots, prints the path and emits screenshot/taken with the path and mode. Bound to SUPER + SHIFT + PRINT.";
        }
        {
          mode = "window";
          title = "Screenshot the active window";
          usage = "Saves the focused window, prints the path and emits screenshot/taken. Bound to SUPER + PRINT.";
        }
        {
          mode = "region";
          title = "Drag a region to screenshot";
          usage = "Lets you drag a rectangle with the mouse, then saves it, prints the path and emits screenshot/taken. Cancelling exits without a file or event. Bound to PRINT.";
        }
        {
          mode = "pick-window";
          title = "Click a window to screenshot";
          usage = "Lets you click any visible window, then saves it, prints the path and emits screenshot/taken.";
        }
        {
          mode = "pick-monitor";
          title = "Click a monitor to screenshot";
          usage = "Lets you click a monitor, then saves it, prints the path and emits screenshot/taken. Not bound to a key.";
        }
        {
          mode = "ocr";
          title = "Drag a region and copy its text";
          usage = "Lets you drag a rectangle, reads the German/English text in it with tesseract, copies it to the clipboard, prints it and emits screenshot/ocr with the text. No image is saved. Bound to SUPER + O.";
        }
      ]
    ++ [
      {
        command = [
          "bus"
          "emit"
        ];
        title = "Emit a schema event onto the bus";
        script = pkgs.writeShellScript "bus-emit.sh" ''
          exec ${t3cron}/bin/t3cron emit "$@"
        '';
        usage = "t3os bus emit <topic> <level> <description> [--attention] [--data <json>] [--source <name>]. Levels: error warn info http verbose debug silly. See nixos/modules/core/eventbus/event.schema.json.";
      }
    ];
  };
}
