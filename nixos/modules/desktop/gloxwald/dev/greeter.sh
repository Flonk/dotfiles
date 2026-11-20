#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEV="$ROOT/.dev"
T=(tmux -L gloxwald-dev -f /dev/null)

theme() { jq -r --arg k "$1" --arg d "$2" '.[$k] // $d' "$DEV/theme.json"; }

build() {
    echo "building gloxwaldgreet"
    cd "$ROOT/src/greeter"
    go build -o "$DEV/gloxwaldgreet" ./cmd/gloxwaldgreet
}

start() {
    local cols=$1 rows=$2
    "${T[@]}" kill-session -t greeter 2>/dev/null || true
    local cmd
    cmd=$(printf 'while :; do env -u TMUX TERM=xterm-kitty COLORTERM=truecolor %q --test --ascii %q --user %q --bg %q --fg %q --accent %q; sleep 0.3; done' \
        "$DEV/gloxwaldgreet" "$ROOT/ascii.txt" "$USER" \
        "$(theme app100 '#0b0e14')" "$(theme app600 '#e6e1cf')" "$(theme wm800 '#ff9624')")
    "${T[@]}" new-session -d -s greeter -x "$cols" -y "$rows" "$cmd" \; \
        set -g status off \; set -g remain-on-exit on
    echo "greeter running at ${cols}x${rows} cells"
}

case "${1:-}" in
build) build ;;
start) start "$2" "$3" ;;
restart) build && start "$2" "$3" ;;
resize) "${T[@]}" resize-window -t greeter -x "$2" -y "$3" ;;
stop) "${T[@]}" kill-server 2>/dev/null || true ;;
*)
    echo "usage: $0 build|start C R|restart C R|resize C R|stop" >&2
    exit 1
    ;;
esac
