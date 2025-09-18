{ ... }:
{
  yuck = ''
    (defwidget sep []
      (box :class "module-2" :vexpand "false" :hexpand "false"
        (label :class "separ" :text "|")))
  '';

  scss = ''
    .separ { color: #3e424f; font-weight: bold; font-size: 22px; margin: 0px 8px 0px 8px; }
  '';
}
