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
      pidfile="''${XDG_RUNTIME_DIR:-/tmp}/autoclicker.pid"
      if [ -f "$pidfile" ] && kill "$(cat "$pidfile")" 2>/dev/null; then
        rm -f "$pidfile"
        notify-send -t 1500 "🖱️ Autoclicker off"
        exit 0
      fi
      ydotool click -r 1000000 -D "''${1:-50}" 0xC0 >/dev/null 2>&1 &
      echo $! > "$pidfile"
      notify-send -t 1500 "🖱️ Autoclicker on"
    '';
  };
in
{
  config = lib.mkIf config.skynet.module.assorted.autoclicker.enable {
    home.packages = [ autoclicker ];

    wayland.windowManager.hyprland.extraConfig = ''
      hl.bind("MOD3 + K", hl.dsp.exec_cmd("autoclicker"))
    '';
  };
}
