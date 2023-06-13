killall polybar

if type "xrandr"; then
  for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
    MONITOR=$m polybar --reload i3 -c ~/.config/polybar/config.ini &
  done
else
  polybar --reload i3 -c ~/.config/polybar/config.ini &
fi
