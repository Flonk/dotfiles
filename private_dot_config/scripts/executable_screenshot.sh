#!/bin/bash

screenshot_dir=~/Pictures/screenshots
mkdir -p "$screenshot_dir"

filename="screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
filepath="$screenshot_dir/$filename"

maim --hidecursor -s "$filepath"
xclip -selection clipboard -t image/png -i "$filepath"

notify-send "Copied to Clipboard" "Saved to $filepath" -i "$filepath"
