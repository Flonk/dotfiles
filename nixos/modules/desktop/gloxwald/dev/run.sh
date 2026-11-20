#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEV="$ROOT/.dev"
mkdir -p "$DEV/events"
cd "$ROOT"

if [[ ! -f "$DEV/theme.json" ]]; then
    cp "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell-theme.json" "$DEV/theme.json" 2>/dev/null || echo '{}' > "$DEV/theme.json"
fi

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

GLOXWALD_ROOT="$ROOT" GLOXWALD_DEV="$DEV" GLOXWALD_THEME="$DEV/theme.json" GLOXWALD_TAB="${1:-desktop}" \
    quickshell --path "$ROOT/src/quickshell/shell/dev.qml"
