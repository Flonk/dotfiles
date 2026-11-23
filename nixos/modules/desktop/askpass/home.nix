{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.t3os.module.desktop.askpass;

  askpass = pkgs.writeShellApplication {
    name = "t3-askpass";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.quickshell
    ];
    text = ''
      prompt="''${1:-Password:}"

      if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
        printf '%s' "$prompt" > /dev/tty
        stty -echo < /dev/tty
        IFS= read -r reply < /dev/tty
        stty echo < /dev/tty
        printf '\n' > /dev/tty
        printf '%s\n' "$reply"
        exit 0
      fi

      secret=true
      case "$prompt" in *yes/no*) secret=false ;; esac
      [ "''${SSH_ASKPASS_PROMPT:-}" = confirm ] && secret=false

      runtime="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      channel="$runtime/t3-askpass.$$"
      rm -f "$channel"
      mkfifo -m 600 "$channel"
      trap 'quickshell ipc call askpass dismiss "$channel" >/dev/null 2>&1; rm -f "$channel"' EXIT

      exec 3<> "$channel"

      quickshell ipc call askpass ask "$prompt" "$channel" "$secret" > /dev/null || exit 1

      IFS= read -r -t ${toString cfg.timeoutSeconds} reply <&3 || exit 1
      case "$reply" in
        +*) printf '%s\n' "''${reply#+}" ;;
        *) exit 1 ;;
      esac
    '';
  };
in
{
  config = lib.mkIf (cfg.enable && config.programs.t3-desktop.quickshell.enable) {
    home.packages = [ askpass ];

    home.sessionVariables = {
      SUDO_ASKPASS = "${askpass}/bin/t3-askpass";
      SSH_ASKPASS = "${askpass}/bin/t3-askpass";
    };
  };
}
