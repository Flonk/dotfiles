{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.programs.gloxwald.quickshell;

  quickshellSrc = builtins.path {
    path = ../quickshell;
    name = "gloxwald-quickshell";
  };

  quickshellConfigDir = "${quickshellSrc}/shell";

  lockScript = pkgs.writeShellScript "gloxwald-lock" ''
    uid=$(id -u)
    for i in $(seq 20); do
      id=$(ls -t /run/user/"$uid"/quickshell/by-id/ 2>/dev/null | head -1)
      if [ -n "$id" ]; then
        ${pkgs.quickshell}/bin/quickshell ipc -i "$id" call lock lock && exit 0
      fi
      sleep 0.5
    done
    exit 1
  '';

in
{
  imports = [
    ./hyprland
    ./stylix.nix
  ];

  options.programs.gloxwald.quickshell = {
    enable = mkEnableOption "gloxwald quickshell bar and lockscreen";

    lockCommand = mkOption {
      type = types.str;
      readOnly = true;
      default = "${lockScript}";
      description = "Command to lock the screen via quickshell IPC. Use this in hyprland binds etc.";
    };
  };

  config = mkIf cfg.enable {
    xdg.configFile."quickshell".source = quickshellConfigDir;

    home.packages = with pkgs; [
      brightnessctl
      inotify-tools
      lm_sensors
      pipewire
      quickshell
    ];

    systemd.user.services.quickshell = {
      Unit = {
        Description = "gloxwald quickshell bar";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.quickshell}/bin/quickshell";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
