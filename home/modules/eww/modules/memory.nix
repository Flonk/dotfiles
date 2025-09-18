{ }:
{
  yuck = ''
    (defwidget mem []
      (box :class "mem_module" :vexpand "false" :hexpand "false"
        (circular-progress :value memory :class "membar" :thickness 4
          (button :class "iconmem" :limit-width 2 :tooltip "using ''${memory}% ram" :onclick "$HOME/.config/eww/scripts/pop system" :show_truncated false :wrap false ""))))
  '';

  scss = ''
    .membar { color: #e0b089; background-color: #38384d; border-radius: 10px; }
    .mem_module { background-color: #0f0f17; border-radius: 16px; margin: 0px 10px 0px 3px; }
    .iconmem { color: #e0b089; font-size: 15; margin: 10px; }
  '';
}
