# figlet utilities

figlet-all() {
  for font in /usr/share/figlet/*.tlf; do
      font_name=$(basename "$font" .tlf)
      figlet -f $font_name "$1"
      echo "$font_name"
      echo
      echo
  done
}

figlet-fzf() {
  ls /usr/share/figlet/*.tlf | xargs -I {} basename "{}" .tlf | fzf \
    --phony --no-mouse --layout reverse \
    --prompt "figlet" \
    --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
    --preview "figlet -f '{}' '{q}'" \
    --header "figlet"
}

: