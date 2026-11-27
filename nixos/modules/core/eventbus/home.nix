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
  screen = pkgs.writeShellApplication {
    name = "t3os-screen";
    runtimeInputs = [
      t3cron
      pkgs.hyprshot
      pkgs.jq
      pkgs.wl-clipboard
      pkgs.libnotify
      pkgs.tesseract
      pkgs.hyprpicker
      pkgs.wf-recorder
      pkgs.slurp
      pkgs.quickshell
      pkgs.pulseaudio
      pkgs.mosquitto
      pkgs.util-linux
      pkgs.coreutils
    ];
    runtimeEnv.T3OS_ACCENT = config.t3os.module.desktop.stylix.accent;
    text = builtins.readFile ./screen.sh;
  };
  registry = lib.importJSON ../../../.registry.json;
  mosquittoConf = pkgs.writeText "mosquitto.conf" ''
    listener 1883 127.0.0.1
    allow_anonymous true
    persistence true
    queue_qos0_messages true
    persistence_location ${config.home.homeDirectory}/.local/state/mosquitto/
  '';
  bridgeScript =
    name:
    let
      host = registry.${name};
      knock = config.t3os.module.core.ssh.knockScript;
      pub = "${pkgs.mosquitto}/bin/mosquitto_pub -h 127.0.0.1";
      tunnel = lib.optionalString (cfg.upstream == name) "-o ExitOnForwardFailure=yes -L 127.0.0.1:18830:127.0.0.1:1883";
    in
    pkgs.writeShellScript "eventbus-bridge-${name}" ''
      seen=$(${pkgs.coreutils}/bin/mktemp)
      trap '${pkgs.coreutils}/bin/rm -f "$seen"' EXIT
      while true; do
        ${lib.optionalString ((host.knock or false) && knock != null) "${knock} ${host.ip} >/dev/null 2>&1 || true"}
        ${pkgs.openssh}/bin/ssh -o BatchMode=yes -o ConnectTimeout=15 -o ServerAliveInterval=20 -o ServerAliveCountMax=3 ${tunnel} \
          ${host.user}@${host.ip} 'PATH="$HOME/.nix-profile/bin:$PATH" exec mosquitto_sub -h 127.0.0.1 -v -t "agent/#"' \
          | while IFS=' ' read -r topic payload; do
              case "$topic" in
              */event)
                [ -n "$payload" ] && ${pub} -t "$topic" -m "$payload"
                continue
                ;;
              */state) ${pkgs.gnugrep}/bin/grep -qxF "$topic" "$seen" || echo "$topic" >> "$seen" ;;
              esac
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
        t3cron emit "systemd/''${unit%.*}/failed" error "$unit failed." --attention --source systemd \
          --data "$(jq -nc --arg detail "$line" --arg scope "$scope" '{detail: $detail, scope: $scope}')"
      done
      for k in "''${!seen[@]}"; do
        [ -n "''${now[$k]:-}" ] && continue
        unit=''${k#*:}
        t3cron emit "systemd/''${unit%.*}/recovered" info "$unit is no longer failed." --source systemd
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
      | jq --unbuffered -c 'select(.member == "Notify") | .payload.data | select(.[6]["x-t3bus"].data != "skip") | {app: (.[0] // ""), summary: (.[3] // ""), body: (.[4] // ""), urgency: (.[6].urgency.data // 1)}' \
      | while read -r n; do
          app=$(jq -r '.app | if . == "" then "unknown" else . end' <<<"$n")
          slug=$(tr -c 'a-zA-Z0-9\n' '-' <<<"$app" | tr 'A-Z' 'a-z')
          summary=$(jq -r -f ${./notify-sentence.jq} <<<"$n")
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
        }) (lib.unique (cfg.bridges ++ lib.optional (cfg.upstream != null) cfg.upstream))
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
        inherit (s) command title;
        usage = s.usage;
        script = pkgs.writeShellScript "screen-${lib.concatStringsSep "-" (lib.tail s.command)}.sh" ''
          exec ${screen}/bin/t3os-screen ${lib.escapeShellArgs (lib.tail s.command)} "$@"
        '';
      })
      [
        {
          command = [
            "screen"
            "shot"
          ];
          title = "Screenshot the active monitor and announce it on the bus";
          usage = "Saves the active monitor, or the one named as an argument (e.g. `t3os screen shot DP-2`), to ~/Pictures/Screenshots, prints the path and emits screen/shot with the path and mode. Takes `monitor`, `window` or `region` as a mode, -c to also copy it and -n for a desktop notification.";
        }
        {
          command = [
            "screen"
            "shot"
            "monitor"
          ];
          title = "Screenshot a monitor";
          usage = "Click a monitor to save it, or pass `--active` for the focused one or a name like `DP-2`. Prints the path and emits screen/shot. -c copies it, -n notifies. SUPER + SHIFT + PRINT runs `monitor --active -c -n`.";
        }
        {
          command = [
            "screen"
            "shot"
            "window"
          ];
          title = "Screenshot a window";
          usage = "Click a window to save it, or pass `--active` for the focused one. Prints the path and emits screen/shot. -c copies it, -n notifies. SUPER + PRINT runs `window --active -c -n`.";
        }
        {
          command = [
            "screen"
            "shot"
            "region"
          ];
          title = "Drag a region to screenshot";
          usage = "Drag a rectangle with the mouse to save it. Prints the path and emits screen/shot; cancelling exits without a file or event. -c copies it, -n notifies. PRINT runs `region -c -n`.";
        }
        {
          command = [
            "screen"
            "record"
          ];
          title = "Record the active monitor";
          usage = "Starts recording the active monitor, or the one named as an argument, to ~/Videos/Recordings and returns at once with the file path. Takes `monitor`, `window` or `region` as a mode like `screen shot`, `--audio` for the default microphone, `--system-audio` for what the default output plays (both are mixed), `--stream [--title TITLE]` to go live on Twitch instead of writing a file (needs the twitch module; it reconnects when the connection drops and relays chat to the bus), -c to copy the file when it stops and -n for notifications. Emits screen/record/started, then screen/record/stopped with the path and length; a timer and stop button sit under the recorded area while it runs.";
        }
        {
          command = [
            "screen"
            "record"
            "monitor"
          ];
          title = "Record a monitor";
          usage = "Click a monitor to record it, or pass `--active` or a name like `DP-2`. Stop with the bar's stop button or `t3os screen record stop`.";
        }
        {
          command = [
            "screen"
            "record"
            "window"
          ];
          title = "Record a window's area";
          usage = "Click a window, or pass `--active` for the focused one; its current rectangle on screen is recorded, so moving the window doesn't follow it. Stop with the bar or `t3os screen record stop`.";
        }
        {
          command = [
            "screen"
            "record"
            "region"
          ];
          title = "Drag a region to record";
          usage = "A white veil covers the screen; drag a rectangle to record it, or press Enter for the whole monitor under the cursor. Hold Shift for advanced mode: Shift+drag or Shift+Enter shows toggles for webcam (w), microphone (m) and system audio (s) plus cancel and ok; the webcam square can be moved and resized inside the region. Ok starts a 3-2-1 countdown, after the camera delivers frames if the webcam is on. Plain drags and Enter record system audio only. A timer and stop button appear below the rectangle. Stop with the bar or `t3os screen record stop`.";
        }
        {
          command = [
            "screen"
            "record"
            "stop"
          ];
          title = "Stop the running recording";
          usage = "Stops wf-recorder, waits for the file to be finished and prints its path.";
        }
        {
          command = [
            "screen"
            "record"
            "status"
          ];
          title = "Show whether a recording is running";
          usage = "Prints `idle`, or what is being recorded, since when and where it is going.";
        }
        {
          command = [
            "screen"
            "ocr"
          ];
          title = "Drag a region and copy its text";
          usage = "Drag a rectangle; its German/English text is read with tesseract, copied to the clipboard, printed and emitted as screen/ocr. No image is saved. -n notifies. Bound to HYPER + O.";
        }
        {
          command = [
            "screen"
            "color-pick"
          ];
          title = "Pick a colour from the screen";
          usage = "Opens hyprpicker's zoom lens; click a pixel to print its hex colour and emit screen/color. -c copies it, -n notifies. HYPER + C runs it with -c -n.";
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
