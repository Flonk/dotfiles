{ }:
{
  yuck = ''
    (defwidget bat []
      (box :class "bat_module" :vexpand "false" :hexpand "false"
        (circular-progress :value battery :class "batbar" :thickness 4
          (button :class "iconbat" :limit-width 2 :tooltip "battery on ''${battery}%" :show_truncated false :onclick "$HOME/.config/eww/scripts/pop system" :wrap false ""))))
  '';

  scss = ''
    .batbar { color: #afbea2; background-color: #38384d; border-radius: 10px; }
    .bat_module { background-color: #0f0f17; border-radius: 16px; margin: 0px 10px 0px 10px; }
    .iconbat { color: #afbea2; font-size: 15; margin: 10px; }
  '';
}
