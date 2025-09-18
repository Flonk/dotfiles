{
  lib ? null,
  pkgs ? null,
  config ? null,
  ...
}:
{
  yuck = ''
    ;; Common variables (no defpolls here)
    (defvar vol_reveal false)
    (defvar br_reveal false)
    (defvar music_reveal false)
    (defvar wifi_rev false)
    (defvar time_rev false)

    (defvar eww "${pkgs.eww}/bin/eww -c $HOME/.config/eww")
  '';

  scss = ''
    *{
      all: unset;
      font-family: ${config.theme.fontFamily.uiNf};
      font-size: ${builtins.toString config.theme.fontSize.big}px;
    }

    tooltip.background { background-color: #0f0f17;  border-radius: 0px; color: #555555; }
    tooltip label { margin: 6px; }

    /** General **/
    .module { margin: 0; border-radius: 0; }

    /* Generic scales */
    scale trough { all: unset; background-color: #22242b; box-shadow: 0 2px 3px 2px #06060b; border-radius: 16px; min-height: 10px; min-width: 70px; margin: 0px 10px 0px 0px; }
  '';

  scripts = [
    {
      path = "eww/scripts/pop";
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        EWW="${pkgs.eww-wayland}/bin/eww"
        CFG="$HOME/.config/eww"
        eww() { "$EWW" -c "$CFG" "$@"; }
        case "''${1:-}" in
          calendar) win="calendar" ;;
          audio) win="audio_ctl" ;;
          system) win="system" ;;
          music) win="music_win" ;;
          *) echo "usage: $0 {calendar|audio|system|music}" >&2; exit 1 ;;
        esac
        if eww windows | grep -q "^$win\\s\+open"; then
          eww close "$win"
        else
          eww open "$win"
        fi
      '';
    }
  ];
}
