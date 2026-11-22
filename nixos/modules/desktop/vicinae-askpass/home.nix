{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.t3os.module.desktop."vicinae-askpass";

  askpass = pkgs.writeShellApplication {
    name = "vicinae-askpass";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      config.programs.vicinae.package
    ];
    text = ''
      prompt="''${1:-Password:}"

      if [ -z "''${WAYLAND_DISPLAY:-}" ] && [ -z "''${DISPLAY:-}" ]; then
        printf '%s' "$prompt" > /dev/tty
        stty -echo < /dev/tty
        IFS= read -r reply < /dev/tty
        stty echo < /dev/tty
        printf '\n' > /dev/tty
        printf '%s\n' "$reply"
        exit 0
      fi

      runtime="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      channel="$runtime/vicinae-askpass.$$"
      rm -f "$channel"
      mkfifo -m 600 "$channel"
      trap 'rm -f "$channel"' EXIT

      exec 3<> "$channel"

      args=$(jq -cn --arg prompt "$prompt" --arg channel "$channel" \
        '{prompt: $prompt, channel: $channel}')
      vicinae deeplink \
        "vicinae://launch/@flo/vicinae-askpass/ask?arguments=$(jq -rn --arg a "$args" '$a | @uri')" \
        > /dev/null

      if ! IFS= read -r -t ${toString cfg.timeoutSeconds} reply <&3; then
        exit 1
      fi
      printf '%s\n' "$reply"
    '';
  };

  extension = inputs.vicinae.lib.${pkgs.stdenv.hostPlatform.system}.mkVicinaeExtension {
    name = "vicinae-askpass";
    version = "0.1.0";
    src = ./extension;
  };
in
{
  config = lib.mkIf (cfg.enable && config.programs.t3-desktop.vicinae.enable) {
    home.packages = [ askpass ];

    programs.vicinae.extensions = [ extension ];

    home.sessionVariables = {
      SUDO_ASKPASS = "${askpass}/bin/vicinae-askpass";
      SSH_ASKPASS = "${askpass}/bin/vicinae-askpass";
    };
  };
}
