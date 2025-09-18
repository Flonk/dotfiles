{ pkgs, ... }:
{
  yuck = ''
    (defpoll clock_time :interval "5m" "date +\%I")
    (defpoll clock_minute :interval "5s" "date +\%M")
    (defpoll clock_date :interval "10h" "date '+%d/%m'")

    (defwidget clock_module []
      (eventbox :onhover "''${eww} update time_rev=true" :onhoverlost "''${eww} update time_rev=false"
        (box :class "module" :space-evenly "false" :orientation "h" :spacing "3"
          (label :text clock_time :class "clock_time_class")
          (label :text "" :class "clock_time_sep")
          (label :text clock_minute :class "clock_minute_class")
          (revealer :transition "slideleft" :reveal time_rev :duration "350ms"
            (button :class "clock_date_class" :onclick "$HOME/.config/eww/scripts/pop calendar" clock_date)))))
  '';

  scss = ''
    .clock_time_sep { font-size: 16; color: #bfc9db; margin: 0px 4px 1px 4px; }
    .clock_time_class, .clock_minute_class { font-size: 23; }
    .clock_date_class { font-size: 18; margin: 0px 20px 0px -1px; color: #d7beda; }
    .clock_minute_class { margin: 0px 20px 0px 3px; color: #bfc9db; }
    .clock_time_class { color: #bfc9db; font-weight: bold; margin: 0px 5px 0px 0px; }
  '';
}
