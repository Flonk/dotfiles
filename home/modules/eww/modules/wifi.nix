{
  lib ? null,
}:
{
  yuck = ''
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
}
