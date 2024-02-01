#!/usr/bin/env bash 
killall polybar

if type "xrandr"; then
  for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
    MONITOR=$m polybar --config=~/.config/polybar/config.ini --reload bottom &
  done
else
  polybar --config=~/.config/polybar/config.ini --reload bottom &
fi