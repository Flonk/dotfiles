{ }:
{
  yuck = ''
    (defpoll song :interval "2s"  "~/.config/eww/scripts/music_info --song")
    (defpoll song_artist :interval "2s"  "~/.config/eww/scripts/music_info --artist")
    (defpoll current_status :interval "1s"  "~/.config/eww/scripts/music_info --time")
    (defpoll song_status :interval "2s"  "~/.config/eww/scripts/music_info --status")
    (defpoll cover_art :interval "2s"  "~/.config/eww/scripts/music_info --cover")

    (defwidget music []
      (eventbox :onhover "''${eww} update music_reveal=true" :onhoverlost "''${eww} update music_reveal=false"
        (box :class "song" :vexpand "false" :hexpand "false"
          (box :class "song_cover_art" :vexpand "false" :hexpand "false" :style "background-image: url(' ''${cover_art}');")
          (box :vexpand "false" :hexpand "false"
            (scale :class "song_progress" :value current_status :vexpand "false" :hexpand "true" :orientation "h" :tooltip song :max 100 :min 0)
            (box :vexpand "false" :hexpand "false"
              (button :class "song_btn_prev" :onclick "$HOME/.config/eww/scripts/music_info --prev" "")
              (button :class "song_btn_toggle" :onclick "$HOME/.config/eww/scripts/music_info --toggle" song_status)
              (button :class "song_btn_next" :onclick "$HOME/.config/eww/scripts/music_info --next" ""))))))
  '';

  scss = ''
    .song { background-color: #0f0f17; border-radius: 16px; }
    .song_cover_art { min-height: 28px; min-width: 28px; background-size: cover; border-radius: 16px; margin: 0px 10px 0px 10px; }
    .song_progress { background-color: #38384d; color: #a1bdce; border-radius: 24px; }
    .song_btn_prev, .song_btn_next, .song_btn_toggle { margin: 0px 8px; }
  '';

  scripts = [
    {
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
    }
  ];
}
