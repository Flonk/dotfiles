#!/bin/bash

echo "hello!"
xrandr --output DP-1-1 --auto --right-of eDP-1
feh --bg-fill ~/assets/background.png
i3-msg reload
i3-msg restart