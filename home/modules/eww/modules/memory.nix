{ ... }:
{
  yuck = ''
    (defpoll memory :interval "15s" "~/.config/eww/scripts/memory")
    (defpoll memory_used_mb :interval "2m" "~/.config/eww/scripts/mem-ad used")
    (defpoll memory_total_mb :interval "2m" "~/.config/eww/scripts/mem-ad total")
    (defpoll memory_free_mb :interval "2m" "~/.config/eww/scripts/mem-ad free")

    (defwidget mem []
      (box :class "mem_module" :vexpand "false" :hexpand "false"
        (circular-progress :value memory :class "membar" :thickness 4
          (button :class "iconmem" :limit-width 2 :tooltip "using ''${memory}% ram" :onclick "$HOME/.config/eww/scripts/pop system" :show_truncated false :wrap false ""))))
  '';

  scss = ''
    .membar { color: #e0b089; background-color: #38384d; border-radius: 10px; }
    .mem_module { background-color: #0f0f17; border-radius: 16px; margin: 0px 10px 0px 3px; }
    .iconmem { color: #e0b089; font-size: 15; margin: 10px; }
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
