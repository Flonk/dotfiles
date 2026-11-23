pub() { mosquitto_pub -h 127.0.0.1 -q 1 "$@" 2>/dev/null; }
event() {
  pub -t mutex/vpn3it/event -m "$(jq -nc --arg ts "$(date +%Y-%m-%dT%H:%M:%S.%3N%:z)" --arg level "$1" --arg desc "$2" --arg state "$3" \
    '{timestamp: $ts, source: "vpn3it-mutex", level: $level, attention: false, description: $desc, data: {state: $state}}')"
}
held() { ip link show tun0 >/dev/null 2>&1 && pgrep -x openconnect >/dev/null; }

released="${XDG_RUNTIME_DIR:-/tmp}/vpn3it-released"
listener=""
if [ "$VPN3IT_PRIORITY" != 1 ]; then
  mosquitto_sub -h 127.0.0.1 -q 1 -t mutex/vpn3it/release | while IFS= read -r who; do
    held || continue
    who=${who:-another host}
    printf '%s\n' "$who" >"$released"
    event warn "Released 3it VPN for $who." released
    /run/wrappers/bin/sudo "$(command -v pkill)" -SIGINT openconnect || true
  done &
  listener=$!
fi

last=""
while true; do
  if [ -n "$listener" ] && ! kill -0 "$listener" 2>/dev/null; then
    echo "release listener died" >&2
    exit 1
  fi
  if held; then state=held desc="3it VPN connected."; else state=free desc="3it VPN disconnected."; fi
  if [ "$state" != "$last" ]; then
    [ -n "$last" ] && event info "$desc" "$state"
    pub -r -t mutex/vpn3it/state -m "$state"
    last=$state
  fi
  sleep 2
done
