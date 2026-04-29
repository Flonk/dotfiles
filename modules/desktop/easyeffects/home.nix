{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.skynet.module.desktop.easyeffects;

  autoBypassScript = pkgs.writeShellScript "easyeffects-auto-bypass.sh" ''
    set -euo pipefail

    SPEAKER_SINK="${cfg.speakerSink}"
    SPEAKER_PRESET="${cfg.speakerPreset}"
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
  config = lib.mkIf cfg.enable {
    services.easyeffects.enable = true;

    home.activation.easyeffectsDb = lib.mkIf (cfg.db != null) (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD mkdir -p "$HOME/.config/easyeffects/db"
        $DRY_RUN_CMD ${pkgs.rsync}/bin/rsync -r --chmod=u+rw \
          ${cfg.db}/ "$HOME/.config/easyeffects/db/"
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

    systemd.user.services.easyeffects-auto-bypass = lib.mkIf (cfg.speakerSink != "") {
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
  };
}
