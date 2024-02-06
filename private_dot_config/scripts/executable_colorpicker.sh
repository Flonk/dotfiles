#!/bin/bash

color=$(maim -s | convert - -alpha off -crop 1x1+0+0 +repage -format '#%[hex:u.p{0,0}]' info: | tr -d '\n')

echo -n $color | xclip -selection clipboard
convert -size 100x100 xc:"$color" /tmp/color_preview.png
notify-send "Color Copied to Clipboard" "Hex: $color" -i /tmp/color_preview.png
rm /tmp/color_preview.png
