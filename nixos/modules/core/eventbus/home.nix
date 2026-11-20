{
  pkgs,
  config,
  lib,
  ...
}:
let
  t3cron = pkgs.rustPlatform.buildRustPackage {
    pname = "t3cron";
    version = "0.1.0";
    src = ./t3cron;
    cargoLock.lockFile = ./t3cron/Cargo.lock;
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.sqlite ];
  };
in
{
  config = lib.mkIf config.skynet.module.core.eventbus.enable {
    home.packages = [
      pkgs.mosquitto
      pkgs.mqtt-explorer
      t3cron
    ];

    systemd.user.services.t3cron = {
      Unit.Description = "t3cron, cron jobs that publish onto the MQTT bus";
      Service = {
        ExecStart = "${t3cron}/bin/t3cron daemon";
        Restart = "always";
        RestartSec = "5s";
      };
      Install.WantedBy = [ "default.target" ];
    };

    skynet.cli.scripts = [
      {
        command = [ "cron" ];
        title = "Manage t3cron jobs on the bus";
        script = pkgs.writeShellScript "cron.sh" ''
          exec ${t3cron}/bin/t3cron "$@"
        '';
        usage = "List, add, remove, run and watch t3cron jobs: skynet cron [list|add <key> <schedule> <topic> [payload]|rm <key>|run <key>|watch]. Schedules are cron expressions or one-shots like 'in 10m' / 'at 18:00'.";
      }
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
  };
}
