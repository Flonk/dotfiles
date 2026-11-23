#!/usr/bin/env bash
set -euo pipefail

dim() { printf '\033[2m%s\033[0m\n' "$*" >&2; }
bold() { printf '\033[1m%s\033[0m\n' "$*" >&2; }
green() { printf '\033[1;32m%s\033[0m\n' "$*" >&2; }

RELEASED="${XDG_RUNTIME_DIR:-/tmp}/vpn3it-released"
rm -f "$RELEASED"

holders() {
  timeout 3 "$MOSQUITTO_SUB" -h 127.0.0.1 -p "$VPN3IT_HUB_PORT" -t mutex/vpn3it/state -t '+/mutex/vpn3it/state' -v --retained-only -W 2 2>/dev/null \
    | $AWK -v self="$VPN3IT_SELF_TOPIC" -v hub="$VPN3IT_HUB_NAME" '$2 == "held" && $1 != self { n = split($1, p, "/"); print (n == 3 ? hub : p[1]) }' || true
}

if [ -n "${VPN3IT_HUB_PORT:-}" ]; then
  HOLDER="$(holders | head -1)"
  if [ -n "$HOLDER" ]; then
    if [ "${VPN3IT_PRIORITY:-0}" != 1 ]; then
      echo "Error: 3it VPN is held by $HOLDER, which has priority. Not connecting." >&2
      exit 75
    fi
    bold "3it VPN is held by $HOLDER, asking it to release..."
    "$MOSQUITTO_PUB" -h 127.0.0.1 -p "$VPN3IT_HUB_PORT" -q 1 -t mutex/vpn3it/release -m "$VPN3IT_HOST_NAME"
    for _ in $(seq 1 30); do
      sleep 1
      [ -z "$(holders)" ] && break
    done
    if [ -n "$(holders)" ]; then
      echo "Error: $HOLDER did not release 3it VPN within 30s." >&2
      exit 1
    fi
    dim "$HOLDER released 3it VPN."
  fi
fi

PRE_DEV="$($IP route show default | $AWK '/^default/ {print $5; exit}')"
PRE_GW="$($IP route show default | $AWK '/^default/ {print $3; exit}')"

PATH="${EXTRA_PATH}:$PATH" \
$PYTHON "$VPN3IT_CONNECT_PY" \
  "$@" \
  "$($BAT -pp "$VPN_HOST_FILE")" \
  "$VPN_USER_FILE" \
  "$VPN_PASS_FILE"

NEW_DEV="tun0"
if ! $IP link show "${NEW_DEV}" > /dev/null 2>&1; then
  dim "Warning: ${NEW_DEV} not found. Waiting up to 30s..."
  for i in $(seq 1 60); do
    $IP link show "${NEW_DEV}" > /dev/null 2>&1 && break
    sleep 0.5
  done
fi

if ! $IP link show "${NEW_DEV}" > /dev/null 2>&1; then
  echo "Error: ${NEW_DEV} never appeared. openconnect may have failed." >&2
  exit 1
fi

dim "VPN device ${NEW_DEV} up, waiting for routing table to stabilize..."

STABLE_ROUNDS=0
PREV_ROUTES=""
for i in $(seq 1 120); do
  CUR_ROUTES="$($IP route show)"
  if [ "${CUR_ROUTES}" = "${PREV_ROUTES}" ]; then
    STABLE_ROUNDS=$((STABLE_ROUNDS + 1))
    if [ "${STABLE_ROUNDS}" -ge 3 ]; then
      dim "Routing table stable after ${i} checks."
      break
    fi
  else
    STABLE_ROUNDS=0
  fi
  PREV_ROUTES="${CUR_ROUTES}"
  sleep 0.5
done

dim "Enforcing default route via ${PRE_DEV}..."
sudo $IP route del default dev "${NEW_DEV}" 2>/dev/null || true
sudo $IP route replace default via "${PRE_GW}" dev "${PRE_DEV}" metric 100

for i in $(seq 1 10); do
  sleep 0.5
  ROGUE="$($IP route show default dev "${NEW_DEV}" 2>/dev/null || true)"
  if [ -n "${ROGUE}" ]; then
    dim "Late VPN default route detected, removing..."
    sudo $IP route del default dev "${NEW_DEV}" 2>/dev/null || true
    sudo $IP route replace default via "${PRE_GW}" dev "${PRE_DEV}" metric 100 2>/dev/null || true
  fi
done

echo ""
green "VPN Connection Established!"
bold "VPN up; internet via ${PRE_DEV}. Press Ctrl+C to disconnect."
echo ""

cleanup() {
  dim "Disconnecting VPN..."
  sudo $PKILL -SIGINT openconnect 2>/dev/null || true
  sleep 1
  sudo $IP route replace default via "${PRE_GW}" dev "${PRE_DEV}" metric 100 2>/dev/null || true
  dim "VPN disconnected."
}
trap cleanup EXIT INT TERM

while $PGREP -x openconnect > /dev/null 2>&1; do
  sleep 2
done

if [ -s "$RELEASED" ]; then
  bold "3it VPN was released for $(cat "$RELEASED")."
  rm -f "$RELEASED"
  exit 75
fi
