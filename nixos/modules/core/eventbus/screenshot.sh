mode="${1:-monitor}"
[ $# -gt 0 ] && shift

target=""
clip=0
notify=0
while [ $# -gt 0 ]; do
  case "$1" in
  -c | --clipboard) clip=1 ;;
  -n | --notify) notify=1 ;;
  -*)
    echo "unknown option: $1" >&2
    exit 2
    ;;
  monitor) [ "$mode" = monitor ] && [ -z "$target" ] || target="$1" ;;
  *) target="$1" ;;
  esac
  shift
done

interactive=false
case "$mode" in
monitor)
  if [ -n "$target" ]; then
    args=(-m output -m "$target")
    what="monitor $target"
  else
    args=(-m output -m active)
    what="the active monitor"
  fi
  ;;
window)
  args=(-m window -m active)
  what="the active window"
  ;;
region)
  args=(-m region)
  what="a region"
  interactive=true
  ;;
pick-window)
  args=(-m window)
  what="a picked window"
  interactive=true
  ;;
pick-monitor)
  args=(-m output)
  what="a picked monitor"
  interactive=true
  ;;
ocr)
  args=(-m region)
  interactive=true
  ;;
*)
  echo "usage: t3os screen shot [monitor [NAME]|window|region|pick-window|pick-monitor|ocr] [-c|--clipboard] [-n|--notify]" >&2
  exit 2
  ;;
esac

if [ "$mode" = ocr ]; then
  text=$(hyprshot "${args[@]}" -r png | tesseract stdin stdout -l deu+eng 2>/dev/null) || true
  if [ -z "${text//[[:space:]]/}" ]; then
    [ "$notify" = 1 ] && notify-send "📸 OCR" "no text found"
    echo "no text recognised" >&2
    exit 1
  fi
  wl-copy <<<"$text"
  [ "$notify" = 1 ] && notify-send "📸 OCR copied" "$(head -c 300 <<<"$text")"
  t3cron emit screenshot/ocr info "text was read off the screen" --source t3os \
    --data "$(jq -nc --arg t "$text" '{detail: ($t | gsub("\\s+"; " ") | .[0:80]), text: $t[0:2000], chars: ($t | length)}')" >/dev/null 2>&1 || true
  printf '%s\n' "$text"
  exit 0
fi

dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d-%H%M%S)_$mode.png"

hyprshot "${args[@]}" -r png >"$file" 2>/dev/null || true
if ! [ -s "$file" ]; then
  rm -f "$file"
  if [ "$interactive" = true ]; then
    echo "screenshot cancelled" >&2
  else
    echo "screenshot failed" >&2
  fi
  exit 1
fi

[ "$clip" = 1 ] && wl-copy --type image/png <"$file"
[ "$notify" = 1 ] && notify-send -i "$file" "📸 Screenshot saved" "$(basename "$file")$([ "$clip" = 1 ] && echo " · copied")"

t3cron emit screenshot/taken info "screenshot of $what" --source t3os \
  --data "$(jq -nc --arg path "$file" --arg mode "$mode" --argjson interactive "$interactive" '{path: $path, detail: ($path | split("/") | last), mode: $mode, interactive: $interactive}')" >/dev/null 2>&1 || true

echo "$file"
