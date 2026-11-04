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
      click() {
        if id -nG | grep -qw ydotool; then
          ydotool click "$1"
        else
          /run/wrappers/bin/sg ydotool -c "ydotool click $1"
        fi
      }
      state="''${XDG_RUNTIME_DIR:-/tmp}/autoclicker.held"
      if [ -f "$state" ]; then
        rm -f "$state"
        click 0x80
        notify-send -t 1500 "🖱️ Left click released"
      else
        touch "$state"
        click 0x40
        notify-send -t 1500 "🖱️ Left click held"
      fi
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
