{ }:
{
  yuck = ''
    (defwidget audio []
      (box :class "audio-box" :orientation "v" :space-evenly "false" :vexpand "false" :hexpand "false"
        (box :halign "v" :space-evenly "false" :hexpand "false" :vexpand "false"
          (box :class "speaker_icon" :orientation "v")
          (box :orientation "v" :halign "center" :vexpand "false" :hexpand "false"
            (label :class "speaker_text" :text "speaker" :valign "center" :halign "left")
            (box :class "speaker_bar" :halign "center" :vexpand "false" :hexpand "false"
              (scale :value volume_percent :space-evenly "false" :orientation "h" :onchange "amixer -D pulse sset Master {}%" :tooltip "volume on ''${volume_percent}%" :max 100 :min 0))))
        (label :text "" :class "audio_sep" :halign "center")
        (box :halign "v" :space-evenly "false" :hexpand "false" :vexpand "false"
          (box :class "mic_icon" :orientation "v")
          (box :orientation "v" :halign "center" :vexpand "false" :hexpand "false"
            (label :class "mic_text" :text "mic" :valign "center" :halign "left")
            (box :class "mic_bar" :halign "center" :vexpand "false" :hexpand "false"
              (scale :value mic_percent :space-evenly "false" :orientation "h" :tooltip "mic on ''${mic_percent}%" :onchange "amixer -D pulse sset Capture {}%" :max 100 :min 0)))))

    (defwindow audio_ctl :geometry (geometry :x "-20px" :y "7%" :anchor "top right" :width "280px" :height "60px") (audio))
  '';

  scss = ''
    .audio-box { background-color: #0f0f17; border-radius: 16px; }
    .speaker_icon { background-size: cover; background-image: url('images/speaker.png'); background-position: center; min-height: 70px; min-width: 75px; margin: 10px 20px 5px 20px; border-radius: 12px; }
    .speaker_text { color: #a1bdce; font-size: 26px; font-weight: bold; margin: 20px 0px 0px 0px; }
    .speaker_bar scale trough highlight { all: unset; background-image: linear-gradient(to right, #afcee0 30%, #a1bdce 50%, #77a5bf 100% *50); border-radius: 24px; }
    .speaker_bar scale trough { all: unset; background-color: #232232; box-shadow: 0 6px 5px 2px #06060b; border-radius: 24px; min-height: 13px; min-width: 120px; margin: 0px 0px 5px 0px; }
    .mic_icon { background-size: cover; background-image: url('images/mic.png'); background-position: center; min-height: 70px; min-width: 75px; margin: 5px 20px 20px 20px; border-radius: 12px; }
    .mic_text { color: #a1bdce; font-size: 26px; font-weight: bold; margin: 0px 0px 0px 0px; }
    .mic_bar scale trough highlight { all: unset; background-image: linear-gradient(to right, #afcee0 30%, #a1bdce 50%, #77a5bf 100% *50); border-radius: 24px; }
    .mic_bar scale trough { all: unset; box-shadow: 0 6px 5px 2px #06060b; background-color: #232232; border-radius: 24px; min-height: 13px; min-width: 120px; margin: 0px 0px 20px 0px; }
    .audio_sep { color: #38384d; font-size: 18; margin: 0px 0px 0px 0px; }
  '';
}
