{ ... }:
{
  yuck = ''
    (defpoll calendar_day :interval "20h" "date '+%d'")
    (defpoll calendar_year :interval "20h" "date '+%Y'")

    (defwidget cal []
      (box :class "cal" :orientation "v"
        (box :class "cal-in"
          (calendar :class "cal" :day calendar_day :year calendar_year))))

    (defwindow calendar :geometry (geometry :x "-20px" :y "7%" :anchor "top right" :width "270px" :height "60px") (cal))
  '';

  scss = ''
    .cal { background-color: #0f0f17; font-family: JetBrainsMono Nerd Font; font-size: 18px; font-weight: normal; }
    .cal-in { padding: 0px 10px 0px 10px; color: #bfc9db; }
    .cal .cal.highlight { padding: 20px; }
    .cal .cal { padding: 5px 5px 5px 5px; margin-left: 10px; }
    calender { color: #bfc9db; }
    calendar:selected { color: #a1bdce; }
    calendar.header { color: #a1bdce; font-weight: bold; }
    calendar.button { color: #afbea2; }
    calendar.highlight { color: #a1bdce; font-weight: bold; }
    calendar:indeterminate { color: #bfc9db; }
  '';
}
