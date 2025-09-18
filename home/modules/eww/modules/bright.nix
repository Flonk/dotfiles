{ pkgs, ... }:
{
  yuck = ''
    (defpoll brightness_percent :interval "5s" "brightnessctl -m -d intel_backlight | awk -F, '{print substr($4, 0, length($4)-1)}' | tr -d '%'")

    (defwidget bright []
      (eventbox :onhover "''${eww} update br_reveal=true" :onhoverlost "''${eww} update br_reveal=false"
        (box :class "module-2" :space-evenly "false" :orientation "h" :spacing "3"
          (label :text "" :class "bright_icon" :tooltip "brightness")
          (revealer :transition "slideleft" :reveal br_reveal :duration "350ms"
            (scale :class "brightbar" :value brightness_percent :orientation "h" :tooltip "''${brightness_percent}%" :max 100 :min 0 :onchange "brightnessctl set {}%")))))
  '';

  scss = ''
    .brightbar trough highlight { background-image: linear-gradient(to right, #e4c9af 30%, #f2cdcd 50%, #e0b089 100% *50); border-radius: 10px; }
    .bright_icon { font-size: 22; color: #e4c9af; margin: 0px 10px 0px 10px; }
  '';
}
