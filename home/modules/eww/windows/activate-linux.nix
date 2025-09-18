{
  lib,
  pkgs,
  config,
}:
let

  yuck = ''
    (defwidget activate-linux []
      (box
        :orientation "v"
        :halign "start"
        :valign "start"
        (label :xalign 0 :markup "<span font_size=\"large\">Activate Linux</span>")
        (label :xalign 0 :text "Go to Settings to activate Linux")))

    (defwindow activate-linux
      :monitor 0
      :stacking "fg"
      :geometry (geometry :x "8px" :y "32px" :width "250px" :anchor "bottom right")
      (activate-linux))
  '';

  scss = ''
    .activate-linux {
      color: rgba(250, 250, 250, 0.5);

      &.background {
        background: none;
      }
    }
  '';

  concatStrings = lib.concatStringsSep "\n";

  yuckAll = concatStrings [
    yuck
  ];

  scssAll = concatStrings [
    scss
  ];

  scriptsAll = [ ];

in
{
  yuck = yuckAll;
  scss = scssAll;
  scripts = scriptsAll;
}
