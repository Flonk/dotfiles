#!/usr/bin/env bash
set -euo pipefail

# --- Color helpers ---
dim() { printf '\033[2m%s\033[0m\n' "$*" >&2; }
bold() { printf '\033[1m%s\033[0m\n' "$*" >&2; }
green() { printf '\033[1;32m%s\033[0m\n' "$*" >&2; }

# --- Snapshot pre-VPN default route ---
PRE_DEV="$($IP route show default | $AWK '/^default/ {print $5; exit}')"
PRE_GW="$($IP route show default | $AWK '/^default/ {print $3; exit}')"

# --- Authenticate & launch openconnect (headless, one Authy prompt) ---
PATH="${EXTRA_PATH}:$PATH" \
$PYTHON "$VPN3IT_CONNECT_PY" \
  "$($BAT -pp "$VPN_HOST_FILE")" \
  "$VPN_USER_FILE" \
  "$VPN_PASS_FILE"

# --- Check for VPN device ---
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

# --- Poll until the routing table stops changing ---
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

# --- Enforce: keep internet on the original interface ---
dim "Enforcing default route via ${PRE_DEV}..."
sudo $IP route del default dev "${NEW_DEV}" 2>/dev/null || true
sudo $IP route replace default via "${PRE_GW}" dev "${PRE_DEV}" metric 100

# Guard: watch for late rogue route changes from openconnect
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

# --- Wait for openconnect to exit (user hits Ctrl+C) ---
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
