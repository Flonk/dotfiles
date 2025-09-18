{
  lib ? null,
  pkgs,
  ...
}:
{
  yuck = ''
    (defpoll COL_WLAN :interval "1m" "~/.config/eww/scripts/wifi --COL")
    (defpoll ESSID_WLAN :interval "1m" "~/.config/eww/scripts/wifi --ESSID")
    (defpoll WLAN_ICON :interval "1m" "~/.config/eww/scripts/wifi --ICON")

    (defwidget wifi []
      (eventbox :onhover "''${eww} update wifi_rev=true"
                :onhoverlost "''${eww} update wifi_rev=false"
        (box :vexpand "false" :hexpand "false" :space-evenly "false"
          (button :class "module-wif" :onclick "networkmanager_dmenu" :wrap "false" :limit-width 12 :style "color: ''${COL_WLAN};" WLAN_ICON)
          (revealer :transition "slideright" :reveal wifi_rev :duration "350ms"
            (label :class "module_essid" :text ESSID_WLAN :orientation "h")))))
  '';

  scss = ''
    .module_essid { font-size: 18; color: #a1bdce; margin: 0px 10px 0px 0px; }
    .module-wif { font-size: 22; color: #a1bdce; border-radius: 100%; margin: 0px 10px 0px 5px; }
  '';

  scripts = [
    {
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
    }
  ];
}
