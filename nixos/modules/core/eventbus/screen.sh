cmd="${1:-}"
[ $# -gt 0 ] && shift

mode=""
target=""
active=0
clip=0
notify=0
audio=0
sysaudio=0
live=0
title=""
sub=""
while [ "$cmd" != _supervise ] && [ $# -gt 0 ]; do
  case "$1" in
  -a | --active) active=1 ;;
  -c | --clipboard) clip=1 ;;
  -n | --notify) notify=1 ;;
  --audio) audio=1 ;;
  --system-audio) sysaudio=1 ;;
  --stream) live=1 ;;
  --title)
    shift
    title="${1:-}"
    ;;
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
       t3os screen record [monitor [--active|NAME]|window [--active]|region] [--audio] [--system-audio] [--stream [--title TITLE]] [-c] [-n]
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

  { hyprshot "${args[@]}" -r png 2>/dev/null || true; } | cat >"$file"
  if ! [ -s "$file" ]; then
    rm -f "$file"
    if [ "$interactive" = true ]; then echo "screenshot cancelled" >&2; else echo "screenshot failed" >&2; fi
    exit 1
  fi

  [ "$clip" = 1 ] && wl-copy --type image/png <"$file"
  [ "$notify" = 1 ] && notify-send -h string:x-t3bus:skip -i "$file" "📸 Screenshot saved$([ "$clip" = 1 ] && echo " and copied to clipboard")" "$(basename "$file")"
  emit screen/shot "Screenshot saved$([ "$clip" = 1 ] && echo " and copied to clipboard")." \
    "$(jq -nc --arg path "$file" --arg mode "$mode" --argjson interactive "$interactive" '{path: $path, detail: ($path | split("/") | last), mode: $mode, interactive: $interactive}')"
  echo "$file"
  ;;

ocr)
  text=$(hyprshot -m region -r png 2>/dev/null | tesseract stdin stdout -l deu+eng 2>/dev/null) || true
  if [ -z "${text//[[:space:]]/}" ]; then
    [ "$notify" = 1 ] && notify-send "OCR" "no text found"
    echo "no text recognised" >&2
    exit 1
  fi
  wl-copy <<<"$text"
  [ "$notify" = 1 ] && notify-send -h string:x-t3bus:skip "📸 OCR copied" "$(head -c 300 <<<"$text")"
  emit screen/ocr "OCR read $(wc -w <<<"$text") words." \
    "$(jq -nc --arg t "$text" '{detail: ($t | gsub("\\s+"; " ") | .[0:80]), text: $t[0:2000], chars: ($t | length)}')"
  printf '%s\n' "$text"
  ;;

color-pick)
  color=$(hyprpicker -l -b 2>/dev/null | sed "s/\x1b\[[0-9;]*m//g" | grep -oE "#[0-9a-f]{6}" | tail -n 1) || true
  if [ -z "$color" ]; then
    echo "no colour picked" >&2
    exit 1
  fi
  [ "$clip" = 1 ] && wl-copy <<<"$color"
  [ "$notify" = 1 ] && notify-send -h string:x-t3bus:skip "🎨 Colour $([ "$clip" = 1 ] && echo copied || echo picked)" "$color"
  emit screen/color "Picked colour $color." "$(jq -nc --arg c "$color" '{detail: $c, color: $c}')"
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
    [ "$clip" = 1 ] && [ -s "$run/last" ] && wl-copy --type text/uri-list <<<"file://$(cat "$run/last")"
    cat "$run/last" 2>/dev/null || true
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
  cam=null
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
    what="a region"
    fifo="$run/pick"
    rm -f "$fifo"
    mkfifo "$fifo"
    exec 3<>"$fifo"
    if ipc=$(qs ipc call recorder pick "$fifo" 2>&1) && [ -z "$ipc" ]; then
      IFS= read -r -t 900 -u 3 picked || picked=""
      exec 3>&-
      rm -f "$fifo"
      if [ -z "$picked" ] || jq -e '.cancel' <<<"$picked" >/dev/null 2>&1; then
        echo "recording cancelled" >&2
        exit 1
      fi
      read -r x y w h < <(jq -r '[.x, .y, .w, .h] | @tsv' <<<"$picked")
      cam=$(jq -c '.cam' <<<"$picked")
      [ "$(jq -r '.mic' <<<"$picked")" = true ] && audio=1
      [ "$(jq -r '.sys' <<<"$picked")" = true ] && sysaudio=1
      if [ "$(jq -r '.live' <<<"$picked")" = true ]; then
        live=1
        title=$(jq -r '.title // ""' <<<"$picked")
      fi
      if [ "$(jq -r '.full' <<<"$picked")" = true ]; then
        output=$(jq -r '.output' <<<"$picked")
        wf=(-o "$output")
        mode=monitor
        what="monitor $output"
      fi
    else
      exec 3>&-
      rm -f "$fifo"
      read -r x y w h < <(pick) || true
    fi
    ;;
  esac
  [ -n "${w:-}" ] && [ "$w" -gt 1 ] && [ "$h" -gt 1 ] || { echo "recording cancelled" >&2; exit 1; }

  if [ -z "$output" ]; then
    w=$((w / 2 * 2))
    h=$((h / 2 * 2))
    output=$(jq -r --argjson x "$x" --argjson y "$y" 'first(.[] | select(.x <= $x and .y <= $y and $x < .x + (.width / .scale) and $y < .y + (.height / .scale)) | .name) // (first(.[] | select(.focused)) | .name)' <<<"$monitors")
    wf=(-g "$x,$y ${w}x$h")
  fi
  if [ "$live" = 1 ]; then
    fail() {
      [ "$notify" = 1 ] && notify-send -u critical -h string:x-t3bus:skip "Twitch" "$1"
      t3cron emit screen/stream/failed error "$1" --source t3os >/dev/null 2>&1 || true
      echo "$1" >&2
      exit 1
    }
    if [ -n "$title" ]; then
      stream_url=$(t3os twitch ingest --title "$title" 2>"$run/twitch.err") || fail "Twitch: $(cat "$run/twitch.err")"
    else
      stream_url=$(t3os twitch ingest 2>"$run/twitch.err") || fail "Twitch: $(cat "$run/twitch.err")"
    fi
    if [ -e /dev/dri/renderD128 ]; then
      wf+=(-c h264_vaapi -d /dev/dri/renderD128 -p rc_mode=CBR -p b=6000k -p maxrate=6000k -p g=60)
    else
      wf+=(-c libx264 -p preset=veryfast -p b=6000k -p maxrate=6000k -p bufsize=12000k -p g=60)
    fi
    wf+=(-r 30 -C aac -P b=160k --muxer=flv)
  fi
  rm -f "$run/modules"
  if [ "$audio" = 1 ] || [ "$sysaudio" = 1 ]; then
    mic=$(pactl get-default-source)
    monitor="$(pactl get-default-sink).monitor"
    if [ "$audio" = 1 ] && [ "$sysaudio" = 1 ]; then
      {
        pactl load-module module-null-sink sink_name=t3os-rec sink_properties=device.description=t3os-rec
        pactl load-module module-loopback source="$mic" sink=t3os-rec latency_msec=20
        pactl load-module module-loopback source="$monitor" sink=t3os-rec latency_msec=20
      } >"$run/modules"
      wf+=(--audio=t3os-rec.monitor)
    elif [ "$audio" = 1 ]; then
      wf+=(--audio="$mic")
    else
      wf+=(--audio="$monitor")
    fi
  fi

  dir="${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings"
  mkdir -p "$dir"
  file="$dir/$(date +%Y-%m-%d-%H%M%S)_${mode:-monitor}.mp4"
  [ "$live" = 1 ] && file=twitch
  jq -nc --arg output "$output" --argjson x "$x" --argjson y "$y" --argjson w "$w" --argjson h "$h" \
    --arg path "$file" --arg mode "${mode:-monitor}" --arg what "$what" --argjson interactive "$interactive" \
    --argjson cam "$cam" --argjson mic "$audio" --argjson sys "$sysaudio" --argjson live "$live" --arg title "$title" --argjson started "$(date +%s%3N)" '{output: $output, x: $x, y: $y, w: $w, h: $h, path: $path, mode: $mode, what: $what, interactive: $interactive, cam: $cam, audio: {mic: ($mic == 1), system: ($sys == 1)}, stream: ($live == 1), title: $title, started: $started}' >"$run/session"
  rm -f "$run/last"

  T3OS_STREAM_URL=${stream_url:-} T3OS_REC_CLIP=$clip T3OS_REC_NOTIFY=$notify setsid -f "$0" _supervise "${wf[@]}" >/dev/null 2>&1 </dev/null
  for _ in $(seq 30); do
    alive && break
    sleep 0.1
  done
  if ! alive; then
    echo "wf-recorder did not start, see $run/wf-recorder.log" >&2
    exit 1
  fi
  if [ "$live" = 1 ]; then
    [ "$notify" = 1 ] && notify-send -h string:x-t3bus:skip -t 2000 "🔴 Live on Twitch" "${title:-$what}"
    echo live
  else
    [ "$notify" = 1 ] && notify-send -h string:x-t3bus:skip -t 2000 "⏺ Recording" "$what"
    echo "$file"
  fi
  ;;

_supervise)
  run="${XDG_RUNTIME_DIR:-/tmp}/t3os-screen-record"
  session=$(cat "$run/session")
  file=$(jq -r .path <<<"$session")
  what=$(jq -r .what <<<"$session")
  started=$(jq -r .started <<<"$session")
  args=()
  while [ $# -gt 0 ]; do args+=("$1"); shift; done
  if [ -n "${T3OS_STREAM_URL:-}" ]; then
    echo $$ >"$run/pid"
    stopping=0
    child=""
    trap 'stopping=1; [ -n "$child" ] && kill -INT "$child" 2>/dev/null' INT TERM
    mosquitto_pub -h 127.0.0.1 -r -t screen/record/state -m "$session" >/dev/null 2>&1 || true
    emit screen/stream/started "Went live on Twitch." "$(jq -c '{detail: .title, title, mode, cam: (.cam != null)}' <<<"$session")"
    setsid t3os twitch relay >/dev/null 2>&1 </dev/null &
    chat=$!
    : >"$run/wf-recorder.log"
    backoff=2
    while [ "$stopping" = 0 ]; do
      began=$(date +%s)
      wf-recorder "${args[@]}" -f "$T3OS_STREAM_URL" > >(sed -u "s#/app/[^ ?']*#/app/<key>#g" >>"$run/wf-recorder.log") 2>&1 &
      child=$!
      while kill -0 "$child" 2>/dev/null; do wait "$child" || true; done
      child=""
      [ "$stopping" = 1 ] && break
      [ $(($(date +%s) - began)) -gt 30 ] && backoff=2
      t3cron emit screen/stream/reconnecting warn "Twitch stream dropped, reconnecting in ${backoff}s." --source t3os --data "$(jq -nc --arg log "$(tail -c 300 "$run/wf-recorder.log")" '{detail: "stream dropped", log: $log}')" >/dev/null 2>&1 || true
      sleep "$backoff" &
      wait $! || true
      backoff=$((backoff < 30 ? backoff * 2 : 30))
    done
    kill -- -"$chat" 2>/dev/null || true
  else
    wf-recorder "${args[@]}" -f "$file" >"$run/wf-recorder.log" 2>&1 &
    echo $! >"$run/pid"
    mosquitto_pub -h 127.0.0.1 -r -t screen/record/state -m "$session" >/dev/null 2>&1 || true
    emit screen/record/started "Started recording $what." "$(jq -c '{detail: (.path | split("/") | last), path, mode, interactive, cam: (.cam != null)}' <<<"$session")"
    wait "$(cat "$run/pid")" || true
  fi
  if [ -f "$run/modules" ]; then
    while read -r id; do pactl unload-module "$id" >/dev/null 2>&1 || true; done <"$run/modules"
    rm -f "$run/modules"
  fi
  rm -f "$run/pid"
  mosquitto_pub -h 127.0.0.1 -r -t screen/record/state -m idle >/dev/null 2>&1 || true
  now=$(date +%s%3N)
  secs=$(((now - started) / 1000))
  if [ -n "${T3OS_STREAM_URL:-}" ]; then
    [ "${T3OS_REC_NOTIFY:-0}" = 1 ] && notify-send -h string:x-t3bus:skip "⏹ Stream ended" "live for ${secs}s"
    emit screen/stream/stopped "Twitch stream ended after ${secs}s." "$(jq -nc --argjson secs "$secs" '{detail: "\($secs)s live", seconds: $secs}')"
  elif [ -s "$file" ]; then
    echo "$file" >"$run/last"
    [ "${T3OS_REC_CLIP:-0}" = 1 ] && wl-copy --type text/uri-list <<<"file://$file"
    [ "${T3OS_REC_NOTIFY:-0}" = 1 ] && notify-send -h string:x-t3bus:skip "⏹ Recording saved" "$(basename "$file") · ${secs}s"
    emit screen/record/stopped "Recorded $what for ${secs}s." "$(jq -nc --arg path "$file" --argjson secs "$secs" --argjson s "$session" '{detail: ($path | split("/") | last), path: $path, seconds: $secs, mode: $s.mode}')"
  else
    rm -f "$file"
    t3cron emit screen/record/failed error "Recording $what failed, wf-recorder produced no file." --source t3os --data "$(jq -nc --arg log "$(tail -c 500 "$run/wf-recorder.log")" '{detail: "wf-recorder produced no file", log: $log}')" >/dev/null 2>&1 || true
  fi
  ;;

*) usage ;;
esac
