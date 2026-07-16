rungs="0.8 1.0 1.25 1.67 2.0 2.5"

case "$1" in
up) delta=1 ;;
down) delta=-1 ;;
*)
  echo "usage: hypr-scale up|down" >&2
  exit 1
  ;;
esac

snapshot=$(hyprctl -j monitors)

id=$(hyprctl -j activewindow | jq -r '.monitor // empty')
if [ -z "$id" ]; then
  id=$(jq -r 'first(.[] | select(.focused) | .id) // empty' <<<"$snapshot")
fi
if [ -z "$id" ]; then
  exit 0
fi

fields='"\(.name) \(.width) \(.height) \(.refreshRate) \(.x) \(.y) \(.scale)"'

info=$(jq -r --argjson id "$id" ".[] | select(.id == \$id) | $fields" <<<"$snapshot")
if [ -z "$info" ]; then
  exit 0
fi
read -r name w h hz x y scale <<<"$info"

new=$(awk -v s="$scale" -v d="$delta" -v rungs="$rungs" 'BEGIN {
  n = split(rungs, r, " ")
  best = 1
  for (i = 2; i <= n; i++) {
    if ((r[i] - s < 0 ? s - r[i] : r[i] - s) < (r[best] - s < 0 ? s - r[best] : r[best] - s)) {
      best = i
    }
  }
  t = best + d
  if (t < 1) t = 1
  if (t > n) t = n
  print r[t]
}')

apply() {
  hyprctl eval \
    "hl.monitor({ output = \"$1\", mode = \"$2x$3@$4\", position = \"$5x$6\", scale = $7 })" 2>&1
}

out=$(apply "$name" "$w" "$h" "$hz" "$x" "$y" "$new")

while read -r n2 w2 h2 hz2 x2 y2 s2; do
  if [ -n "$n2" ]; then
    apply "$n2" "$w2" "$h2" "$hz2" "$x2" "$y2" "$s2" >/dev/null
  fi
done < <(jq -r --argjson id "$id" ".[] | select(.id != \$id) | $fields" <<<"$snapshot")

if [ "$out" = "ok" ]; then
  actual=$(hyprctl -j monitors | jq -r --argjson id "$id" '.[] | select(.id == $id) | .scale')
  notify-send -t 1500 -h "string:x-canonical-private-synchronous:hypr-scale" \
    "🖥 $name" "scale $scale → $actual"
else
  notify-send -t 3000 -h "string:x-canonical-private-synchronous:hypr-scale" \
    "🖥 $name" "scale $new rejected: $out"
fi
