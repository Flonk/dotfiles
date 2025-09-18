{ }:
{
  yuck = ''
    (deflisten workspace "~/.config/eww/scripts/workspace")
    (defwidget workspaces []
      (literal :content workspace))
  '';

  scss = ''
    .works { font-size: 27px; font-weight: normal; margin: 5px 0px 0px 20px; background-color: #0f0f17; }
    .0 , .01, .02, .03, .04, .05, .06,
    .011, .022, .033, .044, .055, .066 { margin: 0px 10px 0px 0px; }
    .0 { color: #3e424f; }
    .01, .02, .03, .04, .05, .06 { color: #bfc9db; }
    .011, .022, .033, .044, .055, .066 { color: #a1bdce; }
  '';

  scripts = [
    {
      path = "eww/scripts/workspace";
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        # Requires: hyprctl, jq
        active=$(hyprctl -j activeworkspace 2>/dev/null | jq -r '.id' 2>/dev/null || echo 1)
        echo -n "(box :class \"works\" :orientation \"h\" "
        for i in 1 2 3 4 5 6; do
          if [ "$i" = "$active" ]; then cls="0''${i}''${i}"; else cls="0''${i}"; fi
          echo -n "(button :class \"$cls\" :onclick \"hyprctl dispatch workspace $i\" \"$i\")"
        done
        echo ")"
      '';
    }
  ];
}
