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
        (label :xalign 0 :class "aclinux-header" :markup "Activate Linux")
        (label :xalign 0 :class "aclinux-text" :text "Go to Settings to activate Linux.")))

    (defwindow activate-linux
      :monitor 0
      :stacking "fg"
      :geometry (geometry :x "157px" :y "13px" :width "250px" :anchor "bottom right")
      (activate-linux))
  '';

  scss = ''
    .activate-linux {
      color: rgba(250, 250, 250, 0.3);
      text-shadow: 0 0 2px rgba(0, 0, 0, 0.3);

      &.background {
        background: none;
      }
    }

    .aclinux-text {
      font-size: 14px;
    }

    .aclinux-header {
      font-size: 20px;
      margin-bottom: 2px;
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
