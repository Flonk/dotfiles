{ pkgs }:
{
  battery = {
    path = "eww/scripts/battery";
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      case "''${1:-}" in
        --bat)
          upower -i $(upower -e | grep BAT) | awk -F: '/percentage/ {gsub(/%/, "", $2); gsub(/ /, "", $2); print $2}'
          ;;
        --bat-st)
          upower -i $(upower -e | grep BAT) | awk -F: '/state/ {gsub(/ /, "", $2); print $2}'
          ;;
        *) echo "usage: $0 {--bat|--bat-st}" >&2; exit 1 ;;
      esac
    '';
  };

  mem_ad = {
    path = "eww/scripts/mem-ad";
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      case "''${1:-}" in
        used)
          free -m | awk '/^Mem:/ { print $3 }'
          ;;
        total)
          free -m | awk '/^Mem:/ { print $2 }'
          ;;
        free)
          free -m | awk '/^Mem:/ { print $4 }'
          ;;
        *) echo "usage: $0 {used|total|free}" >&2; exit 1 ;;
      esac
    '';
  };

  memory = {
    path = "eww/scripts/memory";
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      # Output memory usage percent (rounded)
      free | awk '/^Mem:/ { printf("%d\n", ($3/$2)*100) }'
    '';
  };

  wifi = {
    path = "eww/scripts/wifi";
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      icon_for() {
        local q=$1
        if [ "$q" -ge 80 ]; then echo ""; elif [ "$q" -ge 60 ]; then echo ""; elif [ "$q" -ge 40 ]; then echo ""; elif [ "$q" -ge 20 ]; then echo ""; else echo "睊"; fi
      }
      essid() { nmcli -t -f active,ssid dev wifi | awk -F: '$1=="yes"{print $2}'; }
      quality() { nmcli -t -f active,signal dev wifi | awk -F: '$1=="yes"{print $2}'; }
      case "''${1:-}" in
        --ESSID) essid ;; 
        --ICON) q=$(quality); icon_for "''${q:-0}" ;;
        --COL) echo "#a1bdce" ;;
        *) echo "usage: $0 {--ESSID|--ICON|--COL}" >&2; exit 1 ;;
      esac
    '';
  };

  music_info = {
    path = "eww/scripts/music_info";
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      # Requires: playerctl, mpc (optional for seek), jq(optional)
      case "''${1:-}" in
        --song)
          playerctl metadata xesam:title 2>/dev/null || echo ""
          ;;
        --artist)
          playerctl metadata xesam:artist 2>/dev/null || echo ""
          ;;
        --time)
          dur=$(playerctl metadata mpris:length 2>/dev/null || echo 0)
          pos=$(playerctl position 2>/dev/null | awk '{print int($1*1000000)}' || echo 0)
          if [ "$dur" -gt 0 ]; then printf "%d\n" $(( pos * 100 / dur )); else echo 0; fi
          ;;
        --status)
          st=$(playerctl status 2>/dev/null || echo Paused)
          if [ "$st" = "Playing" ]; then echo ""; else echo ""; fi
          ;;
        --cover)
          # Try to extract art url; fallback to empty
          playerctl metadata mpris:artUrl 2>/dev/null | sed 's#^file://##' || echo ""
          ;;
        --toggle) playerctl play-pause ;;
        --next) playerctl next ;;
        --prev) playerctl previous ;;
        *) echo "usage: $0 {--song|--artist|--time|--status|--cover|--toggle|--next|--prev}" >&2; exit 1 ;;
      esac
    '';
  };
}
