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
    SPEAKER_PRESET="${cfg.easyeffects.speakerPreset}"
    PASSTHROUGH_PRESET="${cfg.easyeffects.passthroughPreset}"
    DEBOUNCE_PID=""
    CURRENT_PRESET=""

    ee() {
      ${pkgs.coreutils}/bin/timeout 5 ${pkgs.easyeffects}/bin/easyeffects "$@" 2>/dev/null || true
    }

    apply_preset() {
      local default_sink target
      default_sink=$(${pkgs.pulseaudio}/bin/pactl info 2>/dev/null \
        | ${pkgs.gnugrep}/bin/grep "Default Sink" \
        | ${pkgs.coreutils}/bin/cut -d: -f2 \
        | ${pkgs.coreutils}/bin/tr -d ' ')
      if [[ "${"\${default_sink,,}"}" == "${"\${SPEAKER_SINK,,}"}" ]]; then
        target="$SPEAKER_PRESET"
      else
        target="$PASSTHROUGH_PRESET"
      fi
      if [[ "$target" != "$CURRENT_PRESET" ]]; then
        ee --load-preset "$target"
        CURRENT_PRESET="$target"
      fi
    }

    schedule_apply() {
      if [[ -n "$DEBOUNCE_PID" ]] && kill -0 "$DEBOUNCE_PID" 2>/dev/null; then
        kill "$DEBOUNCE_PID" 2>/dev/null || true
      fi
      (sleep 1.5 && apply_preset) &
      DEBOUNCE_PID=$!
    }

    # Wait for easyeffects to become reachable
    for _ in $(seq 1 10); do
      ${pkgs.coreutils}/bin/timeout 3 ${pkgs.easyeffects}/bin/easyeffects -p 2>/dev/null && break
      sleep 2
    done

    apply_preset

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
          command = [
            "easyeffects"
            "sync"
          ];
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
