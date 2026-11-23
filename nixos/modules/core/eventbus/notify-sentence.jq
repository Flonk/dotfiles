def clean: gsub("<[^>]*>"; "") | gsub("\\s+"; " ") | ltrimstr(" ") | rtrimstr(" ");
def stop: if test("[.!?…]$") then . else . + "." end;
(.summary | clean) as $s
| ((.body | split("\n")[0]) // "" | clean) as $b
| if $s == "" and $b == "" then "\(.app) sent an empty notification."
  elif $b == "" then $s | stop
  elif $s == "" then $b | stop
  elif ($b | test("^(Connected|Disconnected)( [0-9]+%)?$")) then
    ($b | capture("^(?<state>[A-Za-z]+)( (?<pct>[0-9]+)%)?$")) as $m
    | "\($s) \($m.state | ascii_downcase)" + (if $m.pct then ", battery at \($m.pct)%." else "." end)
  else "\($s): \($b)" | stop
  end
