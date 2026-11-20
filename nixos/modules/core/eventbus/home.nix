{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.skynet.module.core.eventbus;
  calbusPy = pkgs.writers.writePython3Bin "calbus" {
    libraries = with pkgs.python3Packages; [
      requests
      paho-mqtt
    ];
    doCheck = false;
  } (builtins.readFile ./src/calbus.py);
  calbus = pkgs.writeShellScriptBin "calbus" ''
    export PATH="${pkgs.libsecret}/bin:${pkgs.xdg-utils}/bin:$PATH"
    exec ${calbusPy}/bin/calbus "$@"
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

      systemd.user.services.calbus = {
        Unit = {
          Description = "Google Calendar events onto the MQTT bus";
          After = [
            "graphical-session.target"
            "gnome-keyring-secrets.service"
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
            client="''${1:-$(ls -t "$HOME"/Downloads/client_secret_*.json 2>/dev/null | head -1)}"
            [ -n "$client" ] || { echo "usage: skynet calendar auth <client_secret.json>"; exit 1; }
            ${calbus}/bin/calbus auth "$client"
            systemctl --user restart calbus
          '';
          usage = "Stores the Google OAuth client (newest ~/Downloads/client_secret_*.json or the given path) and a refresh token in the keyring, then restarts calbus.";
        }
      ];
    })
  ];
}
