{
  config,
  lib,
  pkgs,
  ...
}:
let
  autoclicker = pkgs.writeShellApplication {
    name = "autoclicker";
    runtimeInputs = with pkgs; [
      ydotool
      libnotify
    ];
    text = ''
      export YDOTOOL_SOCKET=/run/ydotoold/socket
      run() {
        if id -nG | grep -qw ydotool; then
          exec "$@"
        else
          exec /run/wrappers/bin/sg ydotool -c "exec $*"
        fi
      }
      dir="''${XDG_RUNTIME_DIR:-/tmp}"
      case "''${1:-hold}" in
        hold)
          state="$dir/autoclicker.held"
          if [ -f "$state" ]; then
            rm -f "$state"
            notify-send -t 1500 "🖱️ Left click released"
            run ydotool click 0x80
          else
            touch "$state"
            notify-send -t 1500 "🖱️ Left click held"
            run ydotool click 0x40
          fi
          ;;
        right)
          pidfile="$dir/autoclicker-right.pid"
          if [ -f "$pidfile" ] && kill "$(cat "$pidfile")" 2>/dev/null; then
            rm -f "$pidfile"
            notify-send -t 1500 "🖱️ Right clicker off"
            exit 0
          fi
          (run ydotool click -r 100000000 -D "''${2:-50}" 0xC1 >/dev/null 2>&1) &
          echo $! > "$pidfile"
          notify-send -t 1500 "🖱️ Right clicker on"
          ;;
        *)
          echo "usage: autoclicker [hold | right [delay_ms]]" >&2
          exit 1
          ;;
      esac
    '';
  };
in
{
  config = lib.mkIf config.skynet.module.assorted.autoclicker.enable {
    home.packages = [ autoclicker ];

    wayland.windowManager.hyprland.extraConfig = ''
      hl.bind("MOD3 + K", hl.dsp.exec_cmd("autoclicker hold"))
      hl.bind("MOD3 + J", hl.dsp.exec_cmd("autoclicker right"))
    '';
  };
}
