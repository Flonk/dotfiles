token=$(cat "$CREDENTIALS_DIRECTORY/token")
peers=" $T3BUS_PEERS "
rules=$(cat "$T3BUS_RULES")
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

  body=$(jq -c --arg topic t3 --arg from "$from" --arg path "$topic" --argjson rules "$rules" '
    def rx:
      split("/") as $s
      | reduce range(0; $s | length) as $i ("";
          . + if $s[$i] == "#" then (if $i == 0 then ".*" else "(/.*)?" end)
              else (if $i > 0 then "/" else "" end)
                + (if $s[$i] == "+" then "[^/]+" else ($s[$i] | gsub("(?<c>[.^$*+?()\\[\\]{}|\\\\])"; "\\\(.c)")) end)
              end)
      | "^" + . + "$";
    "\($from)/\($path)" as $full
    | ([$rules | to_entries[] | select(.key as $k | $full | test($k | rx))] | max_by(.key | length) | .value) as $rule
    | select($rule != "drop")
    | ({error: 4, warn: 3, info: 2}[.level] // 1) as $p
    | ((.data | objects | .detail | strings) // "") as $d
    | {
        topic: $topic,
        title: "\($from) · \(.source)",
        message: (.description + (if $d != "" then "\n" + $d else "" end)),
        priority: ($rule // ([$p + (if .attention then 1 else 0 end), 5] | min)),
        tags: [$from, .level, $path]
      }' <<<"$payload") || continue
  [ -n "$body" ] || continue

  curl -fsS -o /dev/null -H "Authorization: Bearer $token" -d "$body" http://127.0.0.1:2586/ || echo "ntfy publish failed for $topic" >&2
done
