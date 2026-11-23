cmd="${1:-}"
[ $# -gt 0 ] && shift

mode=""
target=""
active=0
clip=0
notify=0
audio=0
sub=""
while [ "$cmd" != _supervise ] && [ $# -gt 0 ]; do
  case "$1" in
  -a | --active) active=1 ;;
  -c | --clipboard) clip=1 ;;
  -n | --notify) notify=1 ;;
  --audio) audio=1 ;;
  -*)
    echo "unknown option: $1" >&2
    exit 2
    ;;
  *)
    if [ -z "$mode" ] && [ -z "$sub" ] && [ "$cmd" = record ] && [[ "$1" =~ ^(stop|status)$ ]]; then
      sub="$1"
    elif [ -z "$mode" ] && [[ "$cmd" =~ ^(shot|record)$ ]] && [[ "$1" =~ ^(monitor|window|region)$ ]]; then
      mode="$1"
    else
      target="$1"
    fi
    ;;
  esac
  shift
done

emit() {
  t3cron emit "$1" info "$2" --source t3os --data "$3" >/dev/null 2>&1 || true
}

usage() {
  cat >&2 <<'USAGE'
usage: t3os screen shot [monitor [--active|NAME]|window [--active]|region] [-c] [-n]
       t3os screen record [monitor [--active|NAME]|window [--active]|region] [--audio] [-c] [-n]
       t3os screen record stop|status
       t3os screen ocr [-n]
       t3os screen color-pick [-c] [-n]
USAGE
  exit 2
}

case "$cmd" in
shot)
  interactive=false
  case "${mode:-default}" in
  default)
    if [ -n "$target" ]; then
      args=(-m output -m "$target")
      what="monitor $target"
    else
      args=(-m output -m active)
      what="the active monitor"
    fi
    mode=monitor
    ;;
  monitor)
    if [ -n "$target" ]; then
      args=(-m output -m "$target")
      what="monitor $target"
    elif [ "$active" = 1 ]; then
      args=(-m output -m active)
      what="the active monitor"
    else
      args=(-m output)
      what="a picked monitor"
      interactive=true
    fi
    ;;
  window)
    if [ "$active" = 1 ]; then
      args=(-m window -m active)
      what="the active window"
    else
      args=(-m window)
      what="a picked window"
      interactive=true
    fi
    ;;
  region)
    args=(-m region)
    what="a region"
    interactive=true
    ;;
  esac

  dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
  mkdir -p "$dir"
  file="$dir/$(date +%Y-%m-%d-%H%M%S)_$mode.png"

  hyprshot "${args[@]}" -r png >"$file" 2>/dev/null || true
  if ! [ -s "$file" ]; then
    rm -f "$file"
    if [ "$interactive" = true ]; then echo "screenshot cancelled" >&2; else echo "screenshot failed" >&2; fi
    exit 1
  fi

  [ "$clip" = 1 ] && wl-copy --type image/png <"$file"
  [ "$notify" = 1 ] && notify-send -i "$file" "📸 Screenshot saved" "$(basename "$file")$([ "$clip" = 1 ] && echo " · copied")"
  emit screen/shot "Took a screenshot of $what." \
    "$(jq -nc --arg path "$file" --arg mode "$mode" --argjson interactive "$interactive" '{path: $path, detail: ($path | split("/") | last), mode: $mode, interactive: $interactive}')"
  echo "$file"
  ;;

ocr)
  text=$(hyprshot -m region -r png 2>/dev/null | tesseract stdin stdout -l deu+eng 2>/dev/null) || true
  if [ -z "${text//[[:space:]]/}" ]; then
    [ "$notify" = 1 ] && notify-send "📸 OCR" "no text found"
    echo "no text recognised" >&2
    exit 1
  fi
  wl-copy <<<"$text"
  [ "$notify" = 1 ] && notify-send "📸 OCR copied" "$(head -c 300 <<<"$text")"
  emit screen/ocr "Read $(wc -w <<<"$text") words of text off the screen." \
    "$(jq -nc --arg t "$text" '{detail: ($t | gsub("\\s+"; " ") | .[0:80]), text: $t[0:2000], chars: ($t | length)}')"
  printf '%s\n' "$text"
  ;;

color-pick)
  color=$(hyprpicker -l -q 2>/dev/null | tail -n 1) || true
  if [ -z "$color" ]; then
    echo "no colour picked" >&2
    exit 1
  fi
  [ "$clip" = 1 ] && wl-copy <<<"$color"
  [ "$notify" = 1 ] && notify-send "🎨 Colour $([ "$clip" = 1 ] && echo copied || echo picked)" "$color"
  emit screen/color "Picked the colour $color." "$(jq -nc --arg c "$color" '{detail: $c, color: $c}')"
  echo "$color"
  ;;

record)
  run="${XDG_RUNTIME_DIR:-/tmp}/t3os-screen-record"
  mkdir -p "$run"
  state() { mosquitto_pub -h 127.0.0.1 -r -t screen/record/state -m "$1" >/dev/null 2>&1 || true; }
  alive() { [ -f "$run/pid" ] && kill -0 "$(cat "$run/pid")" 2>/dev/null; }

  case "$sub" in
  stop)
    if ! alive; then
      echo "not recording" >&2
      exit 1
    fi
    kill -INT "$(cat "$run/pid")"
    for _ in $(seq 100); do
      [ -f "$run/pid" ] || break
      sleep 0.1
    done
    cat "$run/last" 2>/dev/null
    exit 0
    ;;
  status)
    if alive; then
      jq -r '"recording \(.mode) on \(.output) since \(.started / 1000 | strflocaltime("%H:%M:%S")) → \(.path)"' "$run/session"
    else
      echo "idle"
    fi
    exit 0
    ;;
  esac

  if alive; then
    echo "already recording (t3os screen record stop)" >&2
    exit 1
  fi

  monitors=$(hyprctl -j monitors)
  logical='{name, x, y, w: (.width / .scale | floor), h: (.height / .scale | floor)}'
  pick() { slurp -b '#ffffff33' -c "${T3OS_ACCENT:-#1d9eb6}ff" -w 2 -f '%x %y %w %h' "$@"; }
  output=""
  interactive=false
  case "${mode:-monitor}" in
  monitor)
    if [ -n "$target" ]; then
      m=$(jq -c --arg n "$target" ".[] | select(.name == \$n) | $logical" <<<"$monitors")
      [ -n "$m" ] || { echo "no monitor named $target" >&2; exit 1; }
    elif [ "$active" = 1 ] || [ -z "$mode" ]; then
      m=$(jq -c "first(.[] | select(.focused)) | $logical" <<<"$monitors")
    else
      interactive=true
      read -r px py _ _ < <(pick -o -r) || { echo "recording cancelled" >&2; exit 1; }
      m=$(jq -c --argjson x "$px" --argjson y "$py" "first(.[] | select(.x <= \$x and \$y >= .y and \$x < .x + (.width / .scale) and \$y < .y + (.height / .scale))) | $logical" <<<"$monitors")
    fi
    output=$(jq -r .name <<<"$m")
    read -r x y w h < <(jq -r '[.x, .y, .w, .h] | @tsv' <<<"$m")
    wf=(-o "$output")
    what="monitor $output"
    ;;
  window)
    if [ "$active" = 1 ]; then
      read -r x y w h < <(hyprctl -j activewindow | jq -r '[.at[0], .at[1], .size[0], .size[1]] | @tsv') || true
      what="the active window"
    else
      interactive=true
      ws=$(jq -c '[.[].activeWorkspace.id]' <<<"$monitors")
      read -r x y w h < <(hyprctl -j clients | jq -r --argjson ws "$ws" '.[] | select(.workspace.id as $w | $ws | index($w)) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' | pick -r) || true
      what="a picked window"
    fi
    ;;
  region)
    interactive=true
    read -r x y w h < <(pick) || true
    what="a region"
    ;;
  esac
  [ -n "${w:-}" ] && [ "$w" -gt 1 ] && [ "$h" -gt 1 ] || { echo "recording cancelled" >&2; exit 1; }

  if [ -z "$output" ]; then
    w=$((w / 2 * 2))
    h=$((h / 2 * 2))
    output=$(jq -r --argjson x "$x" --argjson y "$y" 'first(.[] | select(.x <= $x and .y <= $y and $x < .x + (.width / .scale) and $y < .y + (.height / .scale)) | .name) // (first(.[] | select(.focused)) | .name)' <<<"$monitors")
    wf=(-g "$x,$y ${w}x$h")
  fi
  [ "$audio" = 1 ] && wf+=(--audio)

  dir="${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings"
  mkdir -p "$dir"
  file="$dir/$(date +%Y-%m-%d-%H%M%S)_${mode:-monitor}.mp4"
  jq -nc --arg output "$output" --argjson x "$x" --argjson y "$y" --argjson w "$w" --argjson h "$h" \
    --arg path "$file" --arg mode "${mode:-monitor}" --arg what "$what" --argjson interactive "$interactive" \
    --argjson started "$(date +%s%3N)" '{output: $output, x: $x, y: $y, w: $w, h: $h, path: $path, mode: $mode, what: $what, interactive: $interactive, started: $started}' >"$run/session"
  rm -f "$run/last"

  T3OS_REC_CLIP=$clip T3OS_REC_NOTIFY=$notify setsid -f "$0" _supervise "${wf[@]}" >/dev/null 2>&1 </dev/null
  for _ in $(seq 30); do
    alive && break
    sleep 0.1
  done
  if ! alive; then
    echo "wf-recorder did not start, see $run/wf-recorder.log" >&2
    exit 1
  fi
  [ "$notify" = 1 ] && notify-send -t 2000 "⏺ Recording" "$what"
  echo "$file"
  ;;

_supervise)
  run="${XDG_RUNTIME_DIR:-/tmp}/t3os-screen-record"
  session=$(cat "$run/session")
  file=$(jq -r .path <<<"$session")
  what=$(jq -r .what <<<"$session")
  started=$(jq -r .started <<<"$session")
  args=()
  while [ $# -gt 0 ]; do args+=("$1"); shift; done
  wf-recorder "${args[@]}" -f "$file" >"$run/wf-recorder.log" 2>&1 &
  echo $! >"$run/pid"
  mosquitto_pub -h 127.0.0.1 -r -t screen/record/state -m "$session" >/dev/null 2>&1 || true
  emit screen/record/started "Started recording $what." "$(jq -c '{detail: (.path | split("/") | last), path, mode, interactive}' <<<"$session")"
  wait "$(cat "$run/pid")" || true
  rm -f "$run/pid"
  mosquitto_pub -h 127.0.0.1 -r -t screen/record/state -m idle >/dev/null 2>&1 || true
  now=$(date +%s%3N)
  secs=$(((now - started) / 1000))
  if [ -s "$file" ]; then
    echo "$file" >"$run/last"
    [ "${T3OS_REC_CLIP:-0}" = 1 ] && wl-copy --type text/uri-list <<<"file://$file"
    [ "${T3OS_REC_NOTIFY:-0}" = 1 ] && notify-send "⏹ Recording saved" "$(basename "$file") · ${secs}s"
    emit screen/record/stopped "Recorded $what for ${secs}s." "$(jq -nc --arg path "$file" --argjson secs "$secs" --argjson s "$session" '{detail: ($path | split("/") | last), path: $path, seconds: $secs, mode: $s.mode}')"
  else
    rm -f "$file"
    t3cron emit screen/record/failed error "Recording $what failed, wf-recorder produced no file." --source t3os --data "$(jq -nc --arg log "$(tail -c 500 "$run/wf-recorder.log")" '{detail: "wf-recorder produced no file", log: $log}')" >/dev/null 2>&1 || true
  fi
  ;;

*) usage ;;
esac
