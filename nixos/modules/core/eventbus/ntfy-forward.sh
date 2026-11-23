token=$(cat "$CREDENTIALS_DIRECTORY/token")
peers=" $T3BUS_PEERS "
declare -A seen
order=()

mosquitto_sub -h 127.0.0.1 -q 1 -c -i t3bus-ntfy-forward -t '#' -F '%r %t %p' | while IFS=' ' read -r retained topic payload; do
  [ "$retained" = 1 ] && continue
  jq -e 'type == "object" and (.description | type == "string") and (.level | type == "string")' <<<"$payload" >/dev/null 2>&1 || continue

  sum=$(md5sum <<<"$payload")
  sum=${sum%% *}
  [ -n "${seen[$sum]:-}" ] && continue
  seen[$sum]=1
  order+=("$sum")
  if [ "${#order[@]}" -gt 500 ]; then
    unset "seen[${order[0]}]"
    order=("${order[@]:1}")
  fi

  from=$T3BUS_HOST
  first=${topic%%/*}
  if [ "$first" != "$topic" ] && [[ "$peers" == *" $first "* ]]; then
    from=$first
    topic=${topic#*/}
  fi
  channel=$(tr -c 'a-zA-Z0-9_\n-' '-' <<<"${topic%%/*}")

  body=$(jq -c --arg topic "t3-$channel" --arg from "$from" --arg path "$topic" '
    ({error: 4, warn: 3, info: 2}[.level] // 1) as $p
    | ((.data | objects | .detail | strings) // "") as $d
    | {
        topic: $topic,
        title: "\($from) · \(.source)",
        message: (.description + (if $d != "" then "\n" + $d else "" end)),
        priority: ([$p + (if .attention then 1 else 0 end), 5] | min),
        tags: [$from, .level, $path]
      }' <<<"$payload") || continue

  curl -fsS -o /dev/null -H "Authorization: Bearer $token" -d "$body" http://127.0.0.1:2586/ || echo "ntfy publish failed for $topic" >&2
done
