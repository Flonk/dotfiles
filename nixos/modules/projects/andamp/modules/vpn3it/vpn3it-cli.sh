usage() {
  cat >&2 <<'EOF'
vpn3it status                         is 3it up here, who holds it, crdp state
vpn3it up [TOKEN]                     connect directly in the background (asks for the Authy token if missing)
vpn3it down | log | run               disconnect, show the log, connect in the foreground
vpn3it doubletunnel up [TOKEN]        connect andamp without the default route, then 3it through it
vpn3it doubletunnel down | status | log | run
vpn3it crdp ARGS...                   drive the client machine over RDP; `vpn3it crdp` alone prints its usage
EOF
  exit 2
}

emit() { command -v t3cron >/dev/null 2>&1 && t3cron emit "$@" --source vpn3it >/dev/null 2>&1 || true; }
held() { ip link show tun0 >/dev/null 2>&1 && pgrep -x openconnect >/dev/null; }
active() { systemctl --user is-active -q "$1"; }

holders() {
  [ -n "${VPN3IT_HUB_PORT:-}" ] || return 0
  timeout 3 mosquitto_sub -h 127.0.0.1 -p "$VPN3IT_HUB_PORT" -t mutex/vpn3it/state -t '+/mutex/vpn3it/state' -v --retained-only -W 2 2>/dev/null |
    awk -v self="$VPN3IT_SELF_TOPIC" -v hub="$VPN3IT_HUB_NAME" '$2 == "held" && $1 != self { n = split($1, p, "/"); print (n == 3 ? hub : p[1]) }' || true
}

ask_token() {
  local t
  if [ -t 0 ]; then
    IFS= read -rsp "Authy token for 3it: " t
    echo >&2
    printf '%s' "$t"
  elif [ -n "${WAYLAND_DISPLAY:-}" ] && command -v t3-askpass >/dev/null; then
    t3-askpass "Authy token for 3it"
  else
    return 1
  fi
}

case "${1:-}" in
crdp)
  shift
  [ -n "${CRDP:-}" ] || {
    echo "error: crdp is not installed on this host" >&2
    exit 2
  }
  if [ "${1:-}" = start ] && ! held; then
    h=$(holders | head -1)
    echo "error: 3it VPN is not up on this host${h:+, $h holds it}. Connect first with vpn3it up (or vpn3it doubletunnel up)." >&2
    exit 75
  fi
  exec "$CRDP" "$@"
  ;;
status)
  if held; then
    if active doubletunnel; then echo "this host: connected through doubletunnel"; else echo "this host: connected"; fi
  elif active vpn3it || active doubletunnel; then
    echo "this host: connecting"
  else
    echo "this host: disconnected"
  fi
  h=$(holders | paste -sd, -)
  if [ -n "$h" ]; then echo "other hosts: $h holds 3it"; else echo "other hosts: none holds 3it"; fi
  c=$(timeout 2 mosquitto_sub -h 127.0.0.1 -t mutex/crdp/state --retained-only -C 1 -W 1 2>/dev/null || true)
  [ -n "$c" ] && echo "crdp: $c"
  exit 0
  ;;
doubletunnel)
  shift
  [ -n "${DOUBLETUNNEL_RUN:-}" ] || {
    echo "error: doubletunnel is not enabled on this host" >&2
    exit 2
  }
  unit=doubletunnel runner=$DOUBLETUNNEL_RUN prefix="doubletunnel " how=" through andamp"
  ;;
up | down | log | run)
  unit=vpn3it runner=$VPN3IT_RUN prefix="" how=""
  ;;
*) usage ;;
esac

tail_log() { journalctl --user -u "$unit" -n "${1:-15}" --no-pager -o cat 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g'; }

cmd=${1:-}
[ $# -gt 0 ] && shift
case "$cmd" in
status) exec "$0" status ;;
up)
  if held; then
    echo "already connected"
    exit 0
  fi
  if active vpn3it || active doubletunnel; then
    echo "error: a connection attempt is already running, check with: vpn3it status" >&2
    exit 1
  fi
  if [ "${VPN3IT_PRIORITY:-0}" != 1 ]; then
    h=$(holders | head -1)
    if [ -n "$h" ]; then
      echo "error: 3it VPN is held by $h, which has priority. Not connecting." >&2
      exit 75
    fi
  fi
  token=${1:-}
  if [ -z "$token" ]; then
    token=$(ask_token) || {
      echo "error: no Authy token, usage: vpn3it ${prefix}up TOKEN" >&2
      exit 2
    }
  fi
  if ! [[ "$token" =~ ^[0-9]{6,8}$ ]]; then
    echo "error: the Authy token must be 6 to 8 digits" >&2
    exit 2
  fi
  emit vpn3it/connecting info "Connecting 3it VPN$how."
  systemctl --user reset-failed "$unit" 2>/dev/null || true
  file="${XDG_RUNTIME_DIR:-/tmp}/$unit-token"
  (
    umask 077
    printf '%s\n' "$token" >"$file"
  )
  systemd-run --user --unit="$unit" --collect --quiet --setenv=PATH="$PATH" \
    sh -c 'tok=$(cat "$0"); rm -f "$0"; printf "%s\n" "$tok" | exec "$1"' "$file" "$runner"
  for i in $(seq 1 150); do
    sleep 1
    if held; then
      echo "connected$how"
      exit 0
    fi
    if [ "$i" -gt 3 ] && ! active "$unit"; then
      echo "error: connection failed, last log lines:" >&2
      tail_log >&2
      exit 1
    fi
  done
  echo "error: not connected after 150s, last log lines:" >&2
  tail_log >&2
  exit 1
  ;;
down)
  if ! active "$unit" && ! held; then
    echo "already disconnected"
    exit 0
  fi
  emit vpn3it/disconnecting info "Disconnecting 3it VPN$how."
  if active "$unit"; then
    systemctl --user stop "$unit"
  else
    /run/wrappers/bin/sudo "$(command -v pkill)" -SIGINT openconnect || true
  fi
  for _ in $(seq 1 20); do
    if ! held; then
      echo "disconnected"
      exit 0
    fi
    sleep 1
  done
  echo "error: 3it is still up after 20s" >&2
  exit 1
  ;;
log) tail_log 40 ;;
run) exec "$runner" "$@" ;;
*) usage ;;
esac
