{ }:
{
  yuck = ''
    (defwidget music []
      (eventbox :onhover "''${eww} update music_reveal=true" :onhoverlost "''${eww} update music_reveal=false"
        (box :class "module-2" :orientation "h" :space-evenly "false" :vexpand "false" :hexpand "false"
          (box :class "song_cover_art" :vexpand "false" :hexpand "false" :style "background-image: url(' ''${cover_art}');")
          (button :class "song" :wrap "true" :onclick "~/.config/eww/scripts/pop music" song)
          (revealer :transition "slideright" :reveal music_reveal :duration "350ms"
            (box :vexpand "false" :hexpand "false" :oreintation "h"
              (button :class "song_btn_prev" :onclick "~/.config/eww/scripts/music_info --prev" "")
              (button :class "song_btn_play" :onclick "~/.config/eww/scripts/music_info --toggle" song_status)
              (button :class "song_btn_next" :onclick "~/.config/eww/scripts/music_info --next" "")))))
  '';

  scss = ''
    .song_cover_art { background-size: cover; background-position: center; min-height: 24px; min-width: 24px; margin: 10px; border-radius: 100px; }
    .song { color: #a1bdce; font-size: 18px; font-weight: bold; margin: 3px 5px 0px 0px; }
    .song_btn_play { color: #a1bdce; font-size: 28px; margin: 3px 0px 0px 5px; }
    .song_btn_prev, .song_btn_next { color: #bfc9db; font-size: 24px; margin: 3px 0px 0px 5px; }
  '';
}
