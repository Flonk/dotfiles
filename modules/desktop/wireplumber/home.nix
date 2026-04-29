{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.skynet.module.desktop.wireplumber;

  autoSwitchScript = pkgs.writeShellScript "wireplumber-auto-switch.sh" ''
    set -euo pipefail

    LAPTOP_SINK="${cfg.laptopSink}"
    DEBOUNCE_PID=""

    update_default() {
      local bt_sink
      bt_sink=$(${pkgs.pulseaudio}/bin/pactl list short sinks 2>/dev/null \
        | ${pkgs.gnugrep}/bin/grep "^[0-9]*${"\t"}bluez_output" \
        | ${pkgs.coreutils}/bin/head -1 \
        | ${pkgs.coreutils}/bin/cut -f2)

      if [[ -n "$bt_sink" ]]; then
        ${pkgs.pulseaudio}/bin/pactl set-default-sink "$bt_sink"
      else
        ${pkgs.pulseaudio}/bin/pactl set-default-sink "$LAPTOP_SINK"
      fi
    }

    schedule_update() {
      if [[ -n "$DEBOUNCE_PID" ]] && kill -0 "$DEBOUNCE_PID" 2>/dev/null; then
        kill "$DEBOUNCE_PID" 2>/dev/null || true
      fi
      (sleep 1 && update_default) &
      DEBOUNCE_PID=$!
    }

    update_default

    ${pkgs.pulseaudio}/bin/pactl subscribe 2>/dev/null \
      | ${pkgs.gnugrep}/bin/grep --line-buffered -E "Event '(change|new|remove)' on (server|sink)" \
      | while read -r _; do
          schedule_update
        done
  '';
in
{
  config = lib.mkIf cfg.enable {
    systemd.user.services.wireplumber-auto-switch = {
      Unit = {
        Description = "Auto-switch default sink to BT headphones when connected";
        After = [
          "graphical-session.target"
          "pipewire-pulse.service"
        ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = autoSwitchScript;
        Restart = "on-failure";
        RestartSec = "3s";
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
