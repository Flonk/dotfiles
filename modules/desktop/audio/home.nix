# IMPORTANT: Before modifying this file, read the audio setup docs:
#   obsidian read path="claude/audio-setup.md"
# There are hard-won rules there (e.g. EasyEffects must not restart on
# rebuild, don't add custom sink-switching services, don't rewrite the
# preset watcher). Violating them will break audio.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.skynet.module.desktop.audio;

  # --- Auto-trust configured Bluetooth headsets ---
  trustScript = pkgs.writeShellScript "bluetooth-trust-headsets" (
    lib.concatMapStrings (p: ''
      echo "Trusting ${p.description} (${p.mac})"
      ${pkgs.bluez}/bin/bluetoothctl trust ${p.mac} || true
    '') cfg.trustedBluetoothHeadsets
  );

  # --- EasyEffects: switch preset based on active sink ---
  autoPresetScript = pkgs.writeShellScript "easyeffects-auto-preset.sh" ''
    set -euo pipefail

    SPEAKER_SINK="${cfg.defaultAudioSink}"
    HEADPHONE_SINK="${cfg.headphoneSink}"
    SPEAKER_PRESET="${cfg.easyeffects.speakerPreset}"
    PASSTHROUGH_PRESET="${cfg.easyeffects.passthroughPreset}"
    DEBOUNCE_PID=""

    log() { echo "[auto-preset] $(${pkgs.coreutils}/bin/date +%H:%M:%S) $*"; }

    ee() {
      log "ee $*"
      local rc=0
      ${pkgs.coreutils}/bin/timeout 5 ${pkgs.easyeffects}/bin/easyeffects "$@" 2>&1 || rc=$?
      log "ee exit=$rc"
      return 0
    }

    get_default_sink() {
      ${pkgs.pulseaudio}/bin/pactl info 2>/dev/null \
        | ${pkgs.gnugrep}/bin/grep "Default Sink" \
        | ${pkgs.coreutils}/bin/cut -d: -f2 \
        | ${pkgs.coreutils}/bin/tr -d ' ' \
        || true
    }

    headphone_jack_plugged() {
      ${pkgs.pulseaudio}/bin/pactl list cards 2>/dev/null \
        | ${pkgs.gnugrep}/bin/grep -A1 "Headphone Jack" \
        | ${pkgs.gnugrep}/bin/grep -q "availability = available" \
        || return 1
    }

    apply_preset() {
      local default_sink target jack_status

      log "apply_preset called"

      # Get default sink, retrying briefly if PipeWire is mid-transition
      default_sink=$(get_default_sink)
      if [[ -z "$default_sink" ]]; then
        log "default sink empty, retrying in 1s…"
        sleep 1
        default_sink=$(get_default_sink)
      fi
      if [[ -z "$default_sink" ]]; then
        log "default sink still empty after retry, giving up"
        return 0
      fi
      log "default_sink=$default_sink"
      log "SPEAKER_SINK=$SPEAKER_SINK"
      log "HEADPHONE_SINK=$HEADPHONE_SINK"

      # When we know the headphone sink, actively switch the default sink
      # based on jack state — WirePlumber won't do this automatically when
      # both sinks coexist (api.acp.auto-profile = false).
      if [[ -n "$HEADPHONE_SINK" ]]; then
        if headphone_jack_plugged; then
          jack_status="plugged"
        else
          jack_status="unplugged"
        fi
        log "headphone jack: $jack_status"

        if [[ "$jack_status" == "plugged" ]]; then
          if [[ "$default_sink" == "$SPEAKER_SINK" ]]; then
            log "jack plugged but on speakers, switching to headphones"
            ${pkgs.pulseaudio}/bin/pactl set-default-sink "$HEADPHONE_SINK" 2>/dev/null || true
          fi
        else
          if [[ "$default_sink" == "$HEADPHONE_SINK" ]]; then
            log "jack unplugged but on headphones, switching to speakers"
            ${pkgs.pulseaudio}/bin/pactl set-default-sink "$SPEAKER_SINK" 2>/dev/null || true
          fi
        fi
        # Re-read after potential switch
        default_sink=$(get_default_sink)
        log "default_sink after jack logic: $default_sink"
        if [[ -z "$default_sink" ]]; then
          log "default sink empty after jack switch, giving up"
          return 0
        fi
      fi

      if [[ "${"\${default_sink,,}"}" == "${"\${SPEAKER_SINK,,}"}" ]]; then
        target="$SPEAKER_PRESET"
      else
        target="$PASSTHROUGH_PRESET"
      fi
      log "loading preset: $target"
      ee --load-preset "$target"
    }

    schedule_apply() {
      log "schedule_apply: debouncing (1.5s)"
      if [[ -n "$DEBOUNCE_PID" ]] && kill -0 "$DEBOUNCE_PID" 2>/dev/null; then
        log "killing previous debounce PID=$DEBOUNCE_PID"
        kill "$DEBOUNCE_PID" 2>/dev/null || true
      fi
      (sleep 1.5 && apply_preset) &
      DEBOUNCE_PID=$!
      log "debounce PID=$DEBOUNCE_PID"
    }

    log "starting, waiting for easyeffects…"

    # Wait for easyeffects to become reachable
    for i in $(seq 1 10); do
      log "probe attempt $i"
      ${pkgs.coreutils}/bin/timeout 3 ${pkgs.easyeffects}/bin/easyeffects -p 2>/dev/null && break
      sleep 2
    done

    log "running initial apply_preset"
    apply_preset

    log "entering pactl subscribe loop"
    ${pkgs.pulseaudio}/bin/pactl subscribe 2>/dev/null \
      | ${pkgs.gnugrep}/bin/grep --line-buffered -E "Event '(change|new|remove)' on (server|sink|card)" \
      | while read -r line; do
          log "event: $line"
          schedule_apply
        done
    log "pactl subscribe loop exited (unexpected)"
  '';

  reloadScript = pkgs.writeShellScript "audio-reload.sh" ''
    set -euo pipefail
    echo "Clearing WirePlumber saved defaults…"
    rm -f ~/.local/state/wireplumber/default-nodes
    echo "Restarting wireplumber…"
    systemctl --user restart wireplumber.service
    sleep 2
    echo "Restarting easyeffects…"
    systemctl --user restart easyeffects.service
    echo "Restarting easyeffects-auto-preset…"
    systemctl --user restart easyeffects-auto-preset.service
    echo "Waiting for EasyEffects to come up…"
    for _ in $(seq 1 10); do
      ${pkgs.coreutils}/bin/timeout 3 ${pkgs.easyeffects}/bin/easyeffects -p 2>/dev/null && break
      sleep 2
    done
    echo "Disabling EasyEffects bypass…"
    ${pkgs.coreutils}/bin/timeout 5 ${pkgs.easyeffects}/bin/easyeffects -b 2 2>/dev/null || true
    echo ""
    echo "Status:"
    systemctl --user --no-pager status easyeffects.service easyeffects-auto-preset.service 2>&1 || true
    echo ""
    echo "Active preset:"
    ${pkgs.coreutils}/bin/timeout 5 ${pkgs.easyeffects}/bin/easyeffects -p 2>/dev/null || echo "(could not query)"
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

      # Override ExecStart/ExecStop to use a profile-stable path so sd-switch
      # doesn't restart the service on every rebuild due to store-path churn.
      systemd.user.services.easyeffects.Service = {
        ExecStart = lib.mkForce "${config.home.profileDirectory}/bin/easyeffects --hide-window --service-mode";
        ExecStop = lib.mkForce "${config.home.profileDirectory}/bin/easyeffects --quit";
      };

      # Tell sd-switch to never restart easyeffects on rebuild — the unit
      # content is stable (profile paths), but sd-switch still triggers a
      # restart because the home-manager-files store path changes.
      systemd.user.services.easyeffects.Unit.X-SwitchMethod = "keep-old";

      # Passthrough preset: empty plugin chain so EasyEffects stays linked but
      # applies no processing.
      home.file.".local/share/easyeffects/output/${cfg.easyeffects.passthroughPreset}.json".text =
        builtins.toJSON {
          output = {
            blocklist = [ ];
            plugins_order = [ ];
          };
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
          command = [ "audio" "reload" ];
          title = "Restart audio services and reset to defaults";
          script = reloadScript;
          usage = "Restarts easyeffects + auto-preset services, sets default sink to speakers, disables bypass, and shows status.";
        }
        {
          command = [ "easyeffects" "sync" ];
          title = "Sync EasyEffects db to repo";
          script = syncScript;
          usage = "Copies ~/.config/easyeffects/db into the dotfiles repo at config/hosts/$host/cache/easyeffects/db/.";
        }
      ];

      systemd.user.services.easyeffects-auto-preset = lib.mkIf (cfg.defaultAudioSink != "") {
        Unit = {
          Description = "Auto-switch EasyEffects preset based on active sink";
          After = [
            "graphical-session.target"
            "easyeffects.service"
          ];
          PartOf = [ "graphical-session.target" ];
          Wants = [ "easyeffects.service" ];
        };
        Service = {
          ExecStart = autoPresetScript;
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
