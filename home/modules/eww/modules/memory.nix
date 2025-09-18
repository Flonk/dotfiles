{ config, ... }:
{
  yuck = ''
    (defpoll memory :interval "5s" "~/.config/eww/scripts/memory")

    (defwidget mem []
      (box :class "mem_module" :vexpand "false" :hexpand "false"
        (circular-progress :value memory :class "membar" :thickness 5 :start-at 50 :clockwise true
          (box :class "iconmem"))))
  '';

  scss = ''
    .membar {
      color: ${config.theme.color.wm600};
      background-color: ${config.theme.color.app300};
      border-radius: 10px;
    }

    .mem_module {  }
    .iconmem { color: transparent; font-size: 15; margin: 10px; }
  '';

  scripts = [
    {
      path = "eww/scripts/mem-ad";
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        case "''${1:-}" in
          used)
            free -m | awk '/^Mem:/ { print $3 }'
            ;;
          total)
            free -m | awk '/^Mem:/ { print $2 }'
            ;;
          free)
            free -m | awk '/^Mem:/ { print $4 }'
            ;;
          *) echo "usage: $0 {used|total|free}" >&2; exit 1 ;;
        esac
      '';
    }
    {
      path = "eww/scripts/memory";
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        # Output memory usage percent (rounded)
        free | awk '/^Mem:/ { printf("%d\n", ($3/$2)*100) }'
      '';
    }
  ];
}
