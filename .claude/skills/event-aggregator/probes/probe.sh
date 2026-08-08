#!/usr/bin/env bash
# Probe a URL for scrapeability. Writes one result file per URL to avoid interleaved stdout.
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/126.0 Safari/537.36"

probe() {
  url="$1"
  host=$(echo "$url" | sed -E 's|https?://([^/]+).*|\1|')
  key=$(echo "$url" | md5sum | cut -c1-10)
  f="pages/$key.html"

  code=$(curl -sL --max-time 30 -A "$UA" -o "$f" -w "%{http_code}" "$url" 2>/dev/null)
  size=$(wc -c < "$f" 2>/dev/null || echo 0)

  ld=$(grep -c 'application/ld+json' "$f" 2>/dev/null | head -1)
  ev=$(grep -oE '"@type":\s*"(Event|TheaterEvent|MusicEvent|ExhibitionEvent|ScreeningEvent|Festival)"' "$f" 2>/dev/null | wc -l)

  rb=$(curl -sL --max-time 12 -A "$UA" "https://$host/robots.txt" 2>/dev/null)
  ai=$(echo "$rb" | grep -icE 'claude|anthropic' | head -1)

  printf "%-4s %8s ld=%-3s ev=%-4s claudeblock=%-2s %s\n" \
    "$code" "$size" "${ld:-0}" "${ev:-0}" "${ai:-0}" "$url" > "res/$key.txt"
}
export -f probe
export UA
mkdir -p pages res
rm -f res/*.txt
xargs -P 8 -I{} bash -c 'probe "$@"' _ {}
cat res/*.txt | sort -t= -k3 -rn
