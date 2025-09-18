{ }:
{
  yuck = ''
    (defwidget left []
      (box :orientation "h" :space-evenly false :halign "end" :class "left_modules"
        (bright)
        (volume)
        (wifi)
        (sep)
        (bat)
        (mem)
        (sep)
        (clock_module)))
  '';

  scss = '''';
}
