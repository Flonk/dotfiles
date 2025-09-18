{ }:
{
  yuck = ''
    (defwidget music_pop []
      (box :class "music_pop" :orientation "h" :space-evenly "false" :vexpand "false" :hexpand "false"
        (box :class "music_cover_art" :vexpand "false" :hexpand "false" :style "background-image: url(' ''${cover_art}');")
        (box :orientation "v" :spacing 20 :space-evenly "false" :vexpand "false" :hexpand "false"
          (label :halign "center" :class "music" :wrap "true" :limit-width 13 :text song)
          (label :halign "center" :class "music_artist" :wrap "true" :limit-width 15 :text song_artist)
          (box :orientation "h" :spacing 15 :halign "center" :space-evenly "false" :vexpand "false" :hexpand "false"
            (button :class "music_btn_prev" :onclick "~/.config/eww/scripts/music_info --prev" "")
            (button :class "music_btn_play" :onclick "~/.config/eww/scripts/music_info --toggle" song_status)
            (button :class "music_btn_next" :onclick "~/.config/eww/scripts/music_info --next" ""))
          (box :class "music_bar" :halign "center" :vexpand "false" :hexpand "false" :space-evenly "false"
            (scale :onscroll "mpc -q seek {}" :min 0 :active "true" :max 100 :value current_status))))

    (defwindow music_win :stacking "fg" :focusable "false" :screen 1
      :geometry (geometry :x "0" :y "7%" :width 428 :height 104 :anchor "top center")
      (music_pop))
  '';

  scss = ''
    .music_pop { background-color: #0f0f17; border-radius: 16px; }
    .music_cover_art { background-size: cover; background-position: center; min-height: 100px; box-shadow: 5px 5px 5px 5px #06060b; min-width: 170px; margin: 20px; border-radius: 20px; }
    .music { color: #a1bdce; font-size: 20px; font-weight: bold; margin: 20px 0px 0px -15px; }
    .music_artist { color: #bbc5d7; font-size: 16px; font-weight: normal; margin: 0px 0px 0px 0px; }
    .music_btn_prev, .music_btn_play, .music_btn_next { font-family: Iosevka Nerd Font; }
    .music_btn_prev { color: #bbc5d7; font-size: 32px; font-weight: normal; margin: 0px 0px 0px 0px; }
    .music_btn_play { color: #a1bdce; font-size: 48px; font-weight: normal; margin: 0px 0px 0px 0px; }
    .music_btn_next { color: #bbc5d7; font-size: 32px; font-weight: normal; margin: 0px 0px 0px 0px; }
    .music_bar scale trough highlight { all: unset; background-image: linear-gradient(to right, #afcee0 30%, #a1bdce 50%, #77a5bf 100% *50); border-radius: 24px; }
    .music_bar scale trough { all: unset; background-color: #232232; box-shadow: 0 6px 5px 2px #06060b; border-radius: 24px; min-height: 13px; min-width: 190px; margin: -10px 10px 20px 0px; }
  '';
}
