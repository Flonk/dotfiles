{
  lib ? null,
  pkgs ? null,
  config ? null,
}:
{
  yuck = ''
    ;; Variables
    (defpoll clock_time :interval "5m" "date +\%I")
    (defpoll clock_minute :interval "5s" "date +\%M")
    (defpoll clock_date :interval "10h" "date '+%d/%m'")
    (defpoll volume_percent :interval "3s" "amixer -D pulse sget Master | grep 'Left:' | awk -F'[][]' '{ print $2 }' | tr -d '%'")
    (defpoll mic_percent :interval "3s" "amixer -D pulse sget Capture | grep 'Left:' | awk -F'[][]' '{ print $2 }' | tr -d '%'")
    (defpoll brightness_percent :interval "5s" "brightnessctl -m -d intel_backlight | awk -F, '{print substr($4, 0, length($4)-1)}' | tr -d '%'")
    (defpoll battery :interval "15s" "~/.config/eww/scripts/battery --bat")
    (defpoll battery_status :interval "1m" "~/.config/eww/scripts/battery --bat-st")
    (defpoll memory :interval "15s" "~/.config/eww/scripts/memory")
    (defpoll memory_used_mb :interval "2m" "~/.config/eww/scripts/mem-ad used")
    (defpoll memory_total_mb :interval "2m" "~/.config/eww/scripts/mem-ad total")
    (defpoll memory_free_mb :interval "2m" "~/.config/eww/scripts/mem-ad free")
    (defvar vol_reveal false)
    (defvar br_reveal false)
    (defvar music_reveal false)
    (defvar wifi_rev false)
    (defvar time_rev false)
    (deflisten workspace "~/.config/eww/scripts/workspace")

    (defvar eww "${pkgs.eww-wayland}/bin/eww -c $HOME/.config/eww")

    (defpoll COL_WLAN :interval "1m" "~/.config/eww/scripts/wifi --COL")
    (defpoll ESSID_WLAN :interval "1m" "~/.config/eww/scripts/wifi --ESSID")
    (defpoll WLAN_ICON :interval "1m" "~/.config/eww/scripts/wifi --ICON")

    (defpoll song :interval "2s"  "~/.config/eww/scripts/music_info --song")
    (defpoll song_artist :interval "2s"  "~/.config/eww/scripts/music_info --artist")
    (defpoll current_status :interval "1s"  "~/.config/eww/scripts/music_info --time")
    (defpoll song_status :interval "2s"  "~/.config/eww/scripts/music_info --status")
    (defpoll cover_art :interval "2s"  "~/.config/eww/scripts/music_info --cover")

    (defpoll calendar_day :interval "20h" "date '+%d'")
    (defpoll calendar_year :interval "20h" "date '+%Y'")
  '';

  scss = ''
    /** EWW.SCSS\n    Created by saimoom **/
    *{ all: unset; font-family: feather; font-family: DaddyTimeMono NF; }

    /** tooltip!! **/
    tooltip.background { background-color: #0f0f17; font-size: 18; border-radius: 10px; color: #bfc9db; }
    tooltip label { margin: 6px; }

    /** General **/
    .module { margin: 0px 0px 0px 0px; border-radius: 10px 16px 0px 10px; }

    /* Generic scales */
    scale trough { all: unset; background-color: #22242b; box-shadow: 0 2px 3px 2px #06060b; border-radius: 16px; min-height: 10px; min-width: 70px; margin: 0px 10px 0px 0px; }
  '';

  scripts = [
    {
      path = "eww/scripts/pop";
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        EWW="${pkgs.eww-wayland}/bin/eww"
        CFG="$HOME/.config/eww"
        eww() { "$EWW" -c "$CFG" "$@"; }
        case "''${1:-}" in
          calendar) win="calendar" ;;
          audio) win="audio_ctl" ;;
          system) win="system" ;;
          music) win="music_win" ;;
          *) echo "usage: $0 {calendar|audio|system|music}" >&2; exit 1 ;;
        esac
        if eww windows | grep -q "^$win\\s\+open"; then
          eww close "$win"
        else
          eww open "$win"
        fi
      '';
    }
    {
      path = "eww/scripts/workspace";
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        # Requires: hyprctl, jq
        active=$(hyprctl -j activeworkspace 2>/dev/null | jq -r '.id' 2>/dev/null || echo 1)
        echo -n "(box :class \"works\" :orientation \"h\" "
        for i in 1 2 3 4 5 6; do
          if [ "$i" = "$active" ]; then cls="0''${i}''${i}"; else cls="0''${i}"; fi
          echo -n "(button :class \"$cls\" :onclick \"hyprctl dispatch workspace $i\" \"$i\")"
        done
        echo ")"
      '';
    }
  ];
}
