{
  monitor ? "eDP-1",
}:
{
  yuck = ''
    (defwidget bar_1 []
      (box :class "bar_class" :orientation "h" (right) (center) (left)))

    (defwindow bar
      :geometry (geometry :x "0%" :y "9px" :width "98%" :height "30px" :anchor "top center")
      :stacking "fg" :windowtype "dock" :monitor "${monitor}"
      (bar_1))
  '';

  scss = ''
    .bar_class { background-color: #0f0f17; border-radius: 16px; }
  '';
}
