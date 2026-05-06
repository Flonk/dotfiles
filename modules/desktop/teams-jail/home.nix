{
  config,
  lib,
  pkgs,
  ...
}:
let
  logFile = "/tmp/teams-jail.log";
  debugPort = "9222";
  fifo = "/tmp/teams-jail.fifo";
  themeDir = ./theme;

  urlencode = pkgs.writeShellScript "urlencode" ''
    ${pkgs.jq}/bin/jq -rn --arg u "$1" '$u|@uri'
  '';

  # Daemon that reads URLs from FIFO and navigates via CDP
  teamsGateway = pkgs.writeShellScript "teams-gateway" ''
    set -euo pipefail

    LOG="${logFile}"
    log() { echo "[gw   $(date +%H:%M:%S.%N)] $*" >> "$LOG"; }

    CDP="http://localhost:${debugPort}"
    FIFO="${fifo}"

    log "gateway starting, waiting for chromium CDP on port ${debugPort}"

    for i in $(seq 1 30); do
      if ${pkgs.curl}/bin/curl -sf "$CDP/json" >/dev/null 2>&1; then
        break
      fi
      sleep 0.5
    done
    log "CDP ready"

    # Inject window.open override into all future documents
    # This forces Teams launcher to navigate in-place instead of opening new tabs
    TABS=$(${pkgs.curl}/bin/curl -sf "$CDP/json" 2>/dev/null || echo "[]")
    WS_URL=$(echo "$TABS" | ${pkgs.jq}/bin/jq -r '.[0].webSocketDebuggerUrl // empty')
    if [[ -n "$WS_URL" ]]; then
      log "injecting window.open override + jail style"
      printf '{"id":1,"method":"Page.addScriptToEvaluateOnNewDocument","params":{"source":"window.open = function(url, target, features) { if (url) { location.href = url; } return null; }; (function(){ var s = document.createElement(\"style\"); s.textContent = \"html { border: 3px solid #b81c1c !important; box-sizing: border-box; }\"; if (document.head) { document.head.appendChild(s); } else { document.addEventListener(\"DOMContentLoaded\", function() { document.head.appendChild(s); }); } })();"}}' \
        | ${pkgs.websocat}/bin/websocat -1 "$WS_URL" >/dev/null 2>&1 || true
      log "overrides injected"
    fi

    while true; do
      if read -r URL < "$FIFO"; then
        log "received URL: $URL"

        TABS=$(${pkgs.curl}/bin/curl -sf "$CDP/json" 2>/dev/null || echo "[]")
        WS_URL=$(echo "$TABS" | ${pkgs.jq}/bin/jq -r '.[0].webSocketDebuggerUrl // empty')

        if [[ -n "$WS_URL" ]]; then
          # Re-inject overrides for the new page
          printf '{"id":1,"method":"Page.addScriptToEvaluateOnNewDocument","params":{"source":"window.open = function(url, target, features) { if (url) { location.href = url; } return null; }; (function(){ var s = document.createElement(\"style\"); s.textContent = \"html { border: 3px solid #b81c1c !important; box-sizing: border-box; }\"; if (document.head) { document.head.appendChild(s); } else { document.addEventListener(\"DOMContentLoaded\", function() { document.head.appendChild(s); }); } })();"}}' \
            | ${pkgs.websocat}/bin/websocat -1 "$WS_URL" >/dev/null 2>&1 || true

          log "navigating to $URL"
          printf '{"id":2,"method":"Page.navigate","params":{"url":"%s"}}' "$URL" \
            | ${pkgs.websocat}/bin/websocat -1 "$WS_URL" >/dev/null 2>&1 || true
          log "navigate sent"
        else
          log "no websocket, opening via HTTP"
          ENCODED=$(${urlencode} "$URL")
          ${pkgs.curl}/bin/curl -sf "$CDP/json/new?$ENCODED" >/dev/null 2>&1 || true
        fi

        # Close any extra tabs Teams may have spawned
        sleep 3
        TABS=$(${pkgs.curl}/bin/curl -sf "$CDP/json" 2>/dev/null || echo "[]")
        TAB_COUNT=$(echo "$TABS" | ${pkgs.jq}/bin/jq 'length')
        if [[ "$TAB_COUNT" -gt 1 ]]; then
          echo "$TABS" | ${pkgs.jq}/bin/jq -r '.[1:][].id' | while read -r EXTRA; do
            log "closing extra tab $EXTRA"
            ${pkgs.curl}/bin/curl -sf "$CDP/json/close/$EXTRA" >/dev/null 2>&1 || true
          done
        fi
      fi
    done
  '';

  teamsJail = pkgs.writeShellScript "teams-jail" ''
    set -euo pipefail

    LOG="${logFile}"
    log() { echo "[jail $(date +%H:%M:%S.%N)] $*" >> "$LOG"; }

    log "=== script invoked with: $*"

    URL="''${1:-https://teams.microsoft.com}"

    # Unwrap Google Calendar redirect URLs
    if [[ "$URL" == *"google.com/url?"* ]]; then
      URL="$(printf '%s' "$URL" | sed 's/.*[?&]q=\([^&]*\).*/\1/' | sed 's/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g' | xargs -0 printf '%b')"
      log "unwrapped URL: $URL"
    fi

    FIFO="${fifo}"
    DATA_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/teams-jail"

    # If jail is already running, send URL to gateway via FIFO
    if [[ -p "$FIFO" ]]; then
      log "FIFO exists, sending URL to gateway"
      echo "$URL" > "$FIFO"
      exit 0
    fi

    log "first launch"

    MEM_MAX="3G"
    CPU_QUOTA="200%"

    mkfifo "$FIFO"
    log "created FIFO at $FIFO"

    # Write URL to FIFO in background — gateway will pick it up after CDP is ready
    (sleep 2 && echo "$URL" > "$FIFO") &
    log "queued URL for gateway"

    # Start chromium with blank page + gateway under cgroup limits
    exec ${pkgs.systemd}/bin/systemd-run --user --scope \
      -p MemoryMax="$MEM_MAX" \
      -p MemorySwapMax=0 \
      -p CPUQuota="$CPU_QUOTA" \
      -p TasksMax=128 \
      --unit="teams-jail-$$" \
      -- ${pkgs.bash}/bin/bash -c '
        trap "rm -f ${fifo}" EXIT
        ${teamsGateway} &
        ${pkgs.chromium}/bin/chromium \
          --ozone-platform=wayland \
          --enable-features=UseOzonePlatform,WebRTCPipeWireCapturer \
          --disable-gpu-compositing \
          --user-data-dir="$1" \
          --no-first-run \
          --disable-sync \
          --class=teams-jail \
          --process-per-site \
          --remote-debugging-port=${debugPort} \
          --js-flags="--max-old-space-size=1536" \
          about:blank
      ' _ "$DATA_DIR"
  '';
in
{
  config = lib.mkIf config.skynet.module.desktop.teams-jail.enable {
    programs.qutebrowser.extraConfig = lib.mkAfter ''
      import subprocess as _sp
      from qutebrowser.api import interceptor as _intc

      if not hasattr(_intc, '_teams_registered'):
          @_intc.register
          def _teams_intercept(info: _intc.Request):
              if info.resource_type != _intc.ResourceType.main_frame:
                  return
              url = info.request_url.toString()
              if 'teams.microsoft.com' not in url:
                  return
              info.block()
              _sp.Popen(['${teamsJail}', url])

          _intc._teams_registered = True
    '';

    xdg.desktopEntries.teams-jail = {
      name = "Teams (Jailed)";
      comment = "MS Teams in a resource-limited browser";
      exec = "${teamsJail} %u";
      terminal = false;
      categories = [ "Network" ];
      mimeType = [ "x-scheme-handler/msteams" ];
    };

    skynet.cli.scripts = [{
      command = [ "teams" "open" ];
      title = "Open Teams (Jailed)";
      script = teamsJail;
      usage = "Launch MS Teams in a resource-limited jailed Chromium (3GB RAM, 2 CPU cores)";
    }];

    wayland.windowManager.hyprland.settings.windowrule = [
      "border_color rgb(FF0000) rgb(880808), match:class teams-jail"
    ];
  };
}
