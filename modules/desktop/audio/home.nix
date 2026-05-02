{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.skynet.module.desktop.audio;

  # --- Auto-switch default sink to BT headphones when connected ---
  autoSwitchScript = pkgs.writeShellScript "audio-auto-switch.sh" ''
    set -euo pipefail

    DEFAULT_SINK="${cfg.defaultAudioSink}"
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
        ${pkgs.pulseaudio}/bin/pactl set-default-sink "$DEFAULT_SINK"
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

  # --- Auto-trust configured Bluetooth headsets ---
  trustScript = pkgs.writeShellScript "bluetooth-trust-headsets" (
    lib.concatMapStrings (p: ''
      echo "Trusting ${p.description} (${p.mac})"
      ${pkgs.bluez}/bin/bluetoothctl trust ${p.mac} || true
    '') cfg.trustedBluetoothHeadsets
  );

  # --- EasyEffects: auto-bypass when not on default sink ---
  autoBypassScript = pkgs.writeShellScript "easyeffects-auto-bypass.sh" ''
    set -euo pipefail

    SPEAKER_SINK="${cfg.defaultAudioSink}"
    SPEAKER_PRESET="${cfg.easyeffects.speakerPreset}"
    DEBOUNCE_PID=""

    apply_bypass() {
      local default_sink
      default_sink=$(${pkgs.pulseaudio}/bin/pactl info 2>/dev/null \
        | ${pkgs.gnugrep}/bin/grep "Default Sink" \
        | ${pkgs.coreutils}/bin/cut -d: -f2 \
        | ${pkgs.coreutils}/bin/tr -d ' ')
      if [[ "${"\${default_sink,,}"}" == "${"\${SPEAKER_SINK,,}"}" ]]; then
        [[ -n "$SPEAKER_PRESET" ]] && ${pkgs.easyeffects}/bin/easyeffects --load-preset "$SPEAKER_PRESET" 2>/dev/null || true
        ${pkgs.easyeffects}/bin/easyeffects --bypass 2 2>/dev/null || true
      else
        ${pkgs.easyeffects}/bin/easyeffects --bypass 1 2>/dev/null || true
      fi
    }

    schedule_apply() {
      if [[ -n "$DEBOUNCE_PID" ]] && kill -0 "$DEBOUNCE_PID" 2>/dev/null; then
        kill "$DEBOUNCE_PID" 2>/dev/null || true
      fi
      (sleep 1.5 && apply_bypass) &
      DEBOUNCE_PID=$!
    }

    apply_bypass

    ${pkgs.pulseaudio}/bin/pactl subscribe 2>/dev/null \
      | ${pkgs.gnugrep}/bin/grep --line-buffered -E "Event '(change|new|remove)' on (server|sink)" \
      | while read -r _; do
          schedule_apply
        done
  '';

  syncScript = pkgs.writeShellScript "easyeffects-sync.sh" ''
    set -euo pipefail
    DOTFILES=~/repos/personal/dotfiles
    HOST=$(hostname -s)
    REPO_DB="$DOTFILES/config/hosts/$HOST/cache/easyeffects/db"
    if [[ ! -d "$REPO_DB" ]]; then
      echo "No easyeffects db directory found for host '$HOST' at $REPO_DB" >&2
      exit 1
    fi
    ${pkgs.rsync}/bin/rsync -r --delete \
      ~/.config/easyeffects/db/ "$REPO_DB/"
    echo "Synced ~/.config/easyeffects/db → $REPO_DB"
  '';
in
{
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      home.packages = [ inputs.balaclava.packages.${pkgs.system}.default ];
    }

    # --- Sink auto-switching ---
    (lib.mkIf (cfg.defaultAudioSink != "") {
      systemd.user.services.audio-auto-switch = {
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
    })

    # --- Bluetooth headset auto-trust ---
    (lib.mkIf (cfg.trustedBluetoothHeadsets != [ ]) {
      systemd.user.services.bluetooth-trust-headsets = {
        Unit = {
          Description = "Auto-trust configured Bluetooth headsets";
          After = [ "graphical-session-pre.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStartPre = "${pkgs.coreutils}/bin/sleep 3";
          ExecStart = "${trustScript}";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    })

    # --- EasyEffects ---
    (lib.mkIf cfg.easyeffects.enable {
      services.easyeffects.enable = true;

      # Override ExecStart/ExecStop to use stable paths (easyeffects is on PATH
      # via home.packages). Without this, sd-switch restarts the service on
      # every rebuild because the nix store path of easyeffects changes.
      systemd.user.services.easyeffects.Service = {
        ExecStart = lib.mkForce "easyeffects --hide-window --service-mode";
        ExecStop = lib.mkForce "easyeffects --quit";
      };

      home.activation.easyeffectsDb = lib.mkIf (cfg.easyeffects.db != null) (
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          _ee_src="${cfg.easyeffects.db}"
          _ee_stamp="$HOME/.config/easyeffects/.last-nix-source"
          if [[ "$(cat "$_ee_stamp" 2>/dev/null)" != "$_ee_src" ]]; then
            $DRY_RUN_CMD mkdir -p "$HOME/.config/easyeffects/db"
            $DRY_RUN_CMD ${pkgs.rsync}/bin/rsync -r --chmod=u+rw \
              "$_ee_src/" "$HOME/.config/easyeffects/db/"
            $DRY_RUN_CMD ${pkgs.coreutils}/bin/echo "$_ee_src" > "$_ee_stamp"
          fi
        ''
      );

      skynet.cli.scripts = [
        {
          command = [
            "easyeffects"
            "sync"
          ];
          title = "Sync EasyEffects db to repo";
          script = syncScript;
          usage = "Copies ~/.config/easyeffects/db into the dotfiles repo at config/hosts/$host/cache/easyeffects/db/.";
        }
      ];

      systemd.user.services.easyeffects-auto-bypass = lib.mkIf (cfg.defaultAudioSink != "") {
        Unit = {
          Description = "Auto-bypass EasyEffects when non-speaker sink is active";
          After = [
            "graphical-session.target"
            "easyeffects.service"
          ];
          PartOf = [ "graphical-session.target" ];
          Wants = [ "easyeffects.service" ];
        };
        Service = {
          ExecStart = autoBypassScript;
          Restart = "on-failure";
          RestartSec = "3s";
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };
    })
  ]);
}
