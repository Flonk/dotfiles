store="${XDG_CONFIG_HOME:-$HOME/.config}/t3os/displays.json"
quiet="${XDG_RUNTIME_DIR:-/tmp}/t3os-display-quiet"

monitors() {
  hyprctl -j monitors all
}

internal() {
  monitors | jq -r '([.[] | select(.name | test("^(eDP|LVDS|DSI)"))] + .)[0].name // empty'
}

key() {
  monitors | jq -r '[.[].description] | sort | join(" | ")'
}

layout() {
  monitors | jq -c '. as $all | [.[] as $m | {
    description: $m.description,
    disabled: $m.disabled,
    mirror: ($m.mirrorOf as $o | if $o == "none" or $o == null then null else ([$all[] | select(.id == ($o | tonumber? // -1) or .name == $o)][0].description // null) end),
    mode: (if $m.disabled then "preferred" else "\($m.width)x\($m.height)@\($m.refreshRate)" end),
    position: "\($m.x)x\($m.y)",
    scale: $m.scale,
    transform: $m.transform
  }] | sort_by(.description)'
}

lua() {
  local out
  out=$(hyprctl eval "$1" 2>&1)
  [ "$out" = ok ] || echo "t3os display: $out" >&2
}

rule() {
  local name=$1 mode=$2 pos=$3 scale=$4 extra=${5:-}
  lua "hl.monitor({ output = \"$name\", mode = \"$mode\", position = \"$pos\", scale = $scale$extra })"
}

hush() {
  date +%s >"$quiet"
}

announce() {
  local what=$1 sentence=$2
  local data
  data=$(jq -cn --arg mode "$what" --argjson layout "$(layout)" '{mode: $mode, detail: ($layout | map(select(.disabled | not) | .description) | join(", ")), layout: $layout}')
  "$T3OS_BIN" bus emit display/changed info "$sentence" --data "$data" >/dev/null 2>&1 || true
  if [ "${NOTIFY:-}" = 1 ]; then
    notify-send -t 2000 -h "string:x-canonical-private-synchronous:t3os-display" "🖥 Displays" "$what"
  fi
}

current_mode() {
  local snap int
  snap=$(monitors)
  int=$(internal)
  jq -r --arg int "$int" '
    if length < 2 then "single"
    elif any(.[]; .mirrorOf != "none" and .mirrorOf != null) then "mirror"
    elif any(.[]; .name == $int and .disabled) then "external"
    elif all(.[]; .name == $int or .disabled) then "internal"
    else "extend" end' <<<"$snap"
}

enable_all() {
  local name any=0
  while read -r name; do
    rule "$name" preferred auto 1
    any=1
  done < <(monitors | jq -r '.[] | select(.disabled or (.mirrorOf != "none" and .mirrorOf != null)) | .name')
  if [ "$any" = 1 ]; then sleep 0.5; fi
}

keep() {
  local name=$1 pos=$2
  local mode scale
  read -r mode scale < <(monitors | jq -r --arg n "$name" '.[] | select(.name == $n) | if .disabled then "preferred 1" else "\(.width)x\(.height)@\(.refreshRate) \(.scale)" end')
  rule "$name" "$mode" "$pos" "$scale"
}

extend() {
  local side=${1:-right}
  case "$side" in right | left | above | below) ;; *)
    echo "usage: t3os settings display extend [right|left|above|below]" >&2
    exit 1
    ;;
  esac
  local int
  int=$(internal)
  hush
  enable_all
  keep "$int" 0x0
  local offset=0 name w h
  local iw ih
  read -r iw ih < <(monitors | jq -r --arg n "$int" '.[] | select(.name == $n) | [((if .transform % 2 == 1 then .height else .width end) / .scale | floor), ((if .transform % 2 == 1 then .width else .height end) / .scale | floor)] | @tsv')
  while read -r name w h; do
    case "$side" in
    right)
      keep "$name" "$((iw + offset))x0"
      offset=$((offset + w))
      ;;
    left)
      offset=$((offset + w))
      keep "$name" "-${offset}x0"
      ;;
    below)
      keep "$name" "0x$((ih + offset))"
      offset=$((offset + h))
      ;;
    above)
      offset=$((offset + h))
      keep "$name" "0x-${offset}"
      ;;
    esac
  done < <(monitors | jq -r --arg n "$int" '.[] | select(.name != $n) | [.name, ((if .transform % 2 == 1 then .height else .width end) / .scale | floor), ((if .transform % 2 == 1 then .width else .height end) / .scale | floor)] | @tsv')
  local where="$side"
  case "$side" in left | right) where="to the $side of" ;; esac
  announce "extend $side" "External displays now extend $where the built-in screen."
}

mirror() {
  local src=${1:-$(internal)}
  monitors | jq -e --arg n "$src" 'any(.[]; .name == $n)' >/dev/null || {
    echo "t3os display: no monitor $src" >&2
    exit 1
  }
  hush
  enable_all
  keep "$src" 0x0
  local name
  while read -r name; do
    rule "$name" preferred auto 1 ", mirror = \"$src\""
  done < <(monitors | jq -r --arg n "$src" '.[] | select(.name != $n) | .name')
  announce "mirror $src" "All displays now mirror $src."
}

only() {
  local want=$1 int keepers
  int=$(internal)
  case "$want" in
  internal) keepers=$(jq -cn --arg n "$int" '[$n]') ;;
  external) keepers=$(monitors | jq -c --arg n "$int" '[.[] | select(.name != $n) | .name]') ;;
  *) keepers=$(jq -cn --arg n "$want" '[$n]') ;;
  esac
  monitors | jq -e --argjson k "$keepers" '[.[] | select(.name as $n | $k | index($n))] | length > 0' >/dev/null || {
    echo "t3os display: nothing to keep on for '$want'" >&2
    exit 1
  }
  hush
  local name x=0 w
  while read -r name w; do
    keep "$name" "${x}x0"
    x=$((x + w))
  done < <(monitors | jq -r --argjson k "$keepers" '.[] | select(.name as $n | $k | index($n)) | [.name, (if .disabled then 0 else ((if .transform % 2 == 1 then .height else .width end) / .scale | floor) end)] | @tsv')
  while read -r name; do
    lua "hl.monitor({ output = \"$name\", disabled = true })"
  done < <(monitors | jq -r --argjson k "$keepers" '.[] | select(.name as $n | $k | index($n) | not) | .name')
  case "$want" in
  internal) announce "only $want" "Only the built-in display is on." ;;
  external) announce "only $want" "Only the external displays are on." ;;
  *) announce "only $want" "Only display $want is on." ;;
  esac
}

cycle() {
  case "$(current_mode)" in
  single)
    NOTIFY=1 announce "only one display connected" "Only one display is connected, so there is nothing to cycle."
    return
    ;;
  extend) mirror ;;
  mirror) only external ;;
  external) only internal ;;
  *) extend ;;
  esac
}

save() {
  local k
  k=$(key)
  mkdir -p "$(dirname "$store")"
  [ -s "$store" ] || echo '{}' >"$store"
  jq --arg k "$k" --argjson l "$(layout)" --arg at "$(date -Iseconds)" '.[$k] = {saved: $at, layout: $l}' "$store" >"$store.tmp" && mv "$store.tmp" "$store"
  echo "saved layout for: $k"
  announce "saved layout" "Saved the current display layout."
}

saved() {
  if [ -s "$store" ]; then jq -c --arg k "$(key)" '.[$k].layout // empty' "$store"; fi
}

restore() {
  local want
  want=$(saved)
  if [ -z "$want" ]; then
    [ "${1:-}" = auto ] || echo "no saved layout for: $(key)" >&2
    return 1
  fi
  [ "$(layout)" = "$want" ] && return 0
  hush
  local snap
  snap=$(monitors)
  local name mode pos scale transform
  while IFS=$'\t' read -r name mode pos scale transform; do
    rule "$name" "$mode" "$pos" "$scale" ", transform = $transform"
  done < <(jq -r --argjson snap "$snap" '.[] | select((.disabled | not) and .mirror == null) | . as $l | [($snap[] | select(.description == $l.description) | .name), .mode, .position, .scale, .transform] | @tsv' <<<"$want")
  local src
  while IFS=$'\t' read -r name src; do
    rule "$name" preferred auto 1 ", mirror = \"$src\""
  done < <(jq -r --argjson snap "$snap" '.[] | select((.disabled | not) and .mirror != null) | . as $l | [($snap[] | select(.description == $l.description) | .name), ($snap[] | select(.description == $l.mirror) | .name)] | @tsv' <<<"$want")
  while read -r name; do
    lua "hl.monitor({ output = \"$name\", disabled = true })"
  done < <(jq -r --argjson snap "$snap" '.[] | select(.disabled) | . as $l | $snap[] | select(.description == $l.description) | .name' <<<"$want")
  announce "restored saved layout" "Restored the saved display layout."
}

forget() {
  local k
  k=$(key)
  [ -s "$store" ] || return 0
  jq --arg k "$k" 'del(.[$k])' "$store" >"$store.tmp" && mv "$store.tmp" "$store"
  echo "forgot layout for: $k"
}

profiles() {
  [ -s "$store" ] || {
    echo "no saved layouts"
    return
  }
  jq -r 'to_entries[] | "\(.value.saved[0:16] | sub("T"; " "))  \(.key)\n" + (.value.layout | map("    \(.description): " + (if .disabled then "off" elif .mirror then "mirror of \(.mirror)" else "\(.mode) at \(.position) ×\(.scale)" end)) | join("\n"))' "$store"
}

status() {
  echo "mode: $(current_mode)"
  monitors | jq -r '.[] | "  \(.name)\t\(.description)\t" + (if .disabled then "off" elif (.mirrorOf != "none" and .mirrorOf != null) then "mirror of \(.mirrorOf)" else "\(.width)x\(.height)@\(.refreshRate | floor)Hz at \(.x)x\(.y) ×\(.scale)" end)' | column -t -s $'\t'
  if [ -n "$(saved)" ]; then echo "saved layout: yes (restored on plug)"; else echo "saved layout: no"; fi
}

watch() {
  local sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
  local ev last=0 now
  sleep 2
  restore auto || true
  socat -U - "UNIX-CONNECT:$sock" | while read -r ev; do
    case "$ev" in
    monitoradded*\>\>* | monitorremoved*\>\>* | configreloaded*)
      now=$(date +%s)
      last=$(cat "$quiet" 2>/dev/null || echo 0)
      [ $((now - last)) -lt 3 ] && continue
      sleep 1
      if ! restore auto && [ "${ev%%>>*}" != configreloaded ]; then
        case "${ev%%>>*}" in
        monitoradded) announce "${ev%%>>*} ${ev#*>>}" "Display ${ev#*>>} was connected." ;;
        *) announce "${ev%%>>*} ${ev#*>>}" "Display ${ev#*>>} was disconnected." ;;
        esac
      fi
      ;;
    esac
  done
}

cmd=${1:-status}
[ $# -gt 0 ] && shift
args=()
for a in "$@"; do
  case "$a" in
  -n | --notify) NOTIFY=1 ;;
  *) args+=("$a") ;;
  esac
done
set -- "${args[@]}"

case "$cmd" in
status | list) status ;;
extend) extend "$@" ;;
mirror) mirror "$@" ;;
only) only "${1:?usage: t3os settings display only <internal|external|NAME>}" ;;
internal | external) only "$cmd" ;;
cycle) cycle ;;
save) save ;;
restore) restore ;;
forget) forget ;;
profiles) profiles ;;
_watch) watch ;;
*)
  echo "usage: t3os-display <status|extend [side]|mirror [source]|only <internal|external|NAME>|cycle|save|restore|forget|profiles> [-n]" >&2
  exit 1
  ;;
esac
