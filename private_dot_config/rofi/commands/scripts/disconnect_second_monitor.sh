#!/bin/bash

xrandr --output DP-1-1 --off
i3-msg reload
i3-msg restart
