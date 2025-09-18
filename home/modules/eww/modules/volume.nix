{ }:
{
  yuck = ''
    (defwidget volume []
      (eventbox :onhover "''${eww} update vol_reveal=true" :onhoverlost "''${eww} update vol_reveal=false"
        (box :class "module-2" :space-evenly "false" :orientation "h" :spacing "3"
          (button :onclick "scripts/pop audio" :class "volume_icon" "")
          (revealer :transition "slideleft" :reveal vol_reveal :duration "350ms"
            (scale :class "volbar" :value volume_percent :orientation "h" :tooltip "''${volume_percent}%" :max 100 :min 0 :onchange "amixer -D pulse sset Master {}%")))))
  '';

  scss = ''
    .volbar trough highlight { background-image: linear-gradient(to right, #afcee0 30%, #a1bdce 50%, #77a5bf 100% *50); border-radius: 10px; }
    .volume_icon { font-size: 22; color: #a1bdce; margin: 0px 10px 0px 10px; }
  '';
}
