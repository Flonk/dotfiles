#!/usr/bin/env bash
set -euo pipefail

dim() { printf '\033[2m%s\033[0m\n' "$*" >&2; }
bold() { printf '\033[1m%s\033[0m\n' "$*" >&2; }

RUN_DIR="${XDG_RUNTIME_DIR:-/tmp}/doubletunnel"
mkdir -p "$RUN_DIR"
chmod 700 "$RUN_DIR"
PID_FILE="$RUN_DIR/openvpn.pid"
LOG_FILE="$RUN_DIR/openvpn.log"

if [ -f "$PID_FILE" ] && sudo kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "Error: andamp tunnel already running (pid $(cat "$PID_FILE"))." >&2
  exit 1
fi

VPN3IT_HOST="$(cat "$VPN_HOST_FILE")"
VPN3IT_HOST="${VPN3IT_HOST#*://}"
VPN3IT_HOST="${VPN3IT_HOST%%/*}"
VPN3IT_HOST="${VPN3IT_HOST%%:*}"
VPN3IT_IP="$(getent ahostsv4 "$VPN3IT_HOST" | $AWK 'NR==1 {print $1}')"
if [ -z "$VPN3IT_IP" ]; then
  echo "Error: could not resolve $VPN3IT_HOST." >&2
  exit 1
fi

cleanup() {
  if [ -f "$PID_FILE" ]; then
    dim "Disconnecting andamp..."
    sudo kill "$(cat "$PID_FILE")" 2>/dev/null || true
    sudo rm -f "$PID_FILE"
  fi
  rm -f "$RUN_DIR/auth" "$RUN_DIR/andamp.ovpn"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

(
  umask 077
  printf '%s\n%s\n' "$(cat "$ANDAMP_USER_FILE")" "$(cat "$ANDAMP_PASS_FILE")" > "$RUN_DIR/auth"
  grep -vE '^(redirect-gateway|user |group |dev )' "$ANDAMP_OVPN_FILE" > "$RUN_DIR/andamp.ovpn"
  cat >> "$RUN_DIR/andamp.ovpn" <<CONF
dev tun-andamp
dev-type tun
auth-user-pass $RUN_DIR/auth
pull-filter ignore "redirect-gateway"
data-ciphers AES-256-GCM:AES-128-GCM:AES-256-CBC
route $VPN3IT_IP 255.255.255.255 vpn_gateway
CONF
)

bold "Connecting andamp..."
sudo rm -f "$LOG_FILE"
sudo "$OPENVPN" --config "$RUN_DIR/andamp.ovpn" --daemon doubletunnel-andamp \
  --writepid "$PID_FILE" --log "$LOG_FILE"

for _ in $(seq 1 60); do
  if sudo grep -q "Initialization Sequence Completed" "$LOG_FILE" 2>/dev/null; then
    break
  fi
  if sudo grep -qE "AUTH_FAILED|Exiting due to fatal error" "$LOG_FILE" 2>/dev/null; then
    echo "Error: andamp connection failed:" >&2
    sudo tail -5 "$LOG_FILE" >&2
    exit 1
  fi
  sleep 0.5
done

if ! sudo grep -q "Initialization Sequence Completed" "$LOG_FILE" 2>/dev/null; then
  echo "Error: andamp did not come up within 30s:" >&2
  sudo tail -5 "$LOG_FILE" >&2
  exit 1
fi
rm -f "$RUN_DIR/auth"

dim "andamp up; routing $VPN3IT_HOST ($VPN3IT_IP) through it."
bold "Connecting 3it..."
"$VPN3IT" "$@"
