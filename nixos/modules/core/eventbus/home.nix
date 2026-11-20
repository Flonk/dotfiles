{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.skynet.module.core.eventbus;
  secretNames = [
    "client_id"
    "client_secret"
    "refresh_token"
  ];
  sopsKey = n: "google_calendar_${n}";
  calbusBin = pkgs.rustPlatform.buildRustPackage {
    pname = "calbus";
    version = "0.1.0";
    src = ./calbus;
    cargoLock.lockFile = ./calbus/Cargo.lock;
  };
  calbus = pkgs.writeShellScriptBin "calbus" ''
    export PATH="${pkgs.xdg-utils}/bin:$PATH"
    ${lib.concatMapStrings (n: ''
      export CALBUS_${lib.toUpper n}_FILE="''${CALBUS_${lib.toUpper n}_FILE:-${config.sops.secrets.${sopsKey n}.path}}"
    '') secretNames}
    exec ${calbusBin}/bin/calbus "$@"
  '';
in
{
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home.packages = [
        pkgs.mosquitto
        pkgs.mqtt-explorer
      ];

      skynet.cli.scripts = [
        {
          command = [
            "bus"
            "watch"
          ];
          title = "Watch every event on the MQTT bus";
          script = pkgs.writeShellScript "bus-watch.sh" ''
            exec ${pkgs.mosquitto}/bin/mosquitto_sub -h 127.0.0.1 -v -t '#' "$@"
          '';
          usage = "Prints every message on the local mosquitto bus with its topic.";
        }
      ];
    })
    (lib.mkIf (cfg.enable && cfg.calendar.enable) {
      home.packages = [ calbus ];

      sops.secrets = lib.genAttrs (map sopsKey secretNames) (key: {
        inherit key;
        sopsFile = ../../../assets/secrets/secrets.json;
      });

      systemd.user.services.calbus = {
        Unit = {
          Description = "Google Calendar events onto the MQTT bus";
          After = [
            "graphical-session.target"
            "sops-nix.service"
          ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${calbus}/bin/calbus run";
          Restart = "always";
          RestartSec = "10s";
          Environment = [
            "CALBUS_CALENDARS=${lib.concatStringsSep "," cfg.calendar.calendars}"
            "CALBUS_SOON_MINUTES=${toString cfg.calendar.soonMinutes}"
          ];
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      skynet.cli.scripts = [
        {
          command = [
            "calendar"
            "auth"
          ];
          title = "Authorize the calendar reader with Google";
          script = pkgs.writeShellScript "calbus-auth.sh" ''
            set -euo pipefail
            export SOPS_AGE_KEY_FILE="''${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
            repo="$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/repos/personal/dotfiles")"
            secrets="$repo/nixos/assets/secrets/secrets.json"
            client="''${1:-}"
            creds="$(${calbus}/bin/calbus auth ''${client:+"$client"})"
            for n in ${lib.concatStringsSep " " secretNames}; do
              ${pkgs.sops}/bin/sops set "$secrets" "[\"google_calendar_$n\"]" "$(echo "$creds" | ${pkgs.jq}/bin/jq -c ".$n")"
            done
            if [ -n "$client" ]; then rm -f -- "$client"; echo "Moved the client from $client into sops."; fi
            echo "Stored the client and refresh token in $secrets, rebuilding."
            skynet rebuild
          '';
          usage = "Runs the Google consent flow and writes the refresh token into sops secrets.json, then rebuilds. Pass the downloaded OAuth client JSON once; it is moved into sops and the file deleted. Later runs reuse the client from sops.";
        }
      ];
    })
  ];
}
