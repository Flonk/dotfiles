{ pkgs, config, ... }:
{
  yuck = ''
    (defpoll clock_datetime :interval "1s" "date +\"%Y-%m-%d %H:%M:%S\"")

    (defwidget clock_module []
      (box :class "module" :space-evenly "false" :orientation "h" :spacing "3"
        (label :text clock_datetime :class "clock_time_class")))
  '';

  scss = ''
    .clock_time_class {  }
  '';
}
