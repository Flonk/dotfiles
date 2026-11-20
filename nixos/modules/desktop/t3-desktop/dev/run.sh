rm -f "$DEV/theme.json"
cat "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell-theme.json" > "$DEV/theme.json" 2>/dev/null || echo '{}' > "$DEV/theme.json"#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEV="$ROOT/.dev"
mkdir -p "$DEV/events"
cd "$ROOT"

rm -f "$DEV/theme.json"
cat "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell-theme.json" > "$DEV/theme.json" 2>/dev/null || echo '{}' > "$DEV/theme.json"

python3 -I dev/bake-chrome.py "$(jq -r '.wm800 // "#1d9eb6"' "$DEV/theme.json")" src/quickshell/shell/chrome/gradient.png src/quickshell/shell/chrome/palette.json "$(jq -r '.ground // ""' "$DEV/theme.json")"

pids=()
cleanup() {
    kill "${pids[@]}" 2>/dev/null || true
    "$ROOT/dev/greeter.sh" stop
    "$ROOT/dev/grub.sh" stop
}
trap cleanup EXIT

watch() {
    local name=$1
    shift
    touch "$DEV/events/$name"
    watchexec --postpone --quiet "$@" -- "date +%s%N > '$DEV/events/$name'" &
    pids+=($!)
}

watch shader -w src/quickshell/lockscreen/shaders/scenes -w src/quickshell/lockscreen/qt_preamble.glsl -w src/quickshell/lockscreen/convert-shaders.sh -e glsl,qml,sh,png,json
watch greeter -w src/greeter -w ascii.txt -e go,mod,sum,txt
watch grub -w src/grub/generate-assets.sh -w dev/grub.sh -w ascii.txt

T3_DESKTOP_ROOT="$ROOT" T3_DESKTOP_DEV="$DEV" T3_DESKTOP_THEME="$DEV/theme.json" T3_DESKTOP_TAB="${1:-desktop}" \
    quickshell --path "$ROOT/src/quickshell/shell/dev.qml"
