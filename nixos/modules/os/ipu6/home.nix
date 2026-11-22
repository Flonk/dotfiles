{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.t3os.module.os.ipu6.enable {
    t3os.cli.scripts = [
      {
        command = [
          "settings"
          "webcam"
          "status"
        ];
        title = "Show the IPU6 webcam relay status";
        script = pkgs.writeShellScript "webcam-status.sh" ''
          systemctl status v4l2-relayd-ipu6.service --no-pager -n 15
        '';
        usage = "Status and recent log lines of `v4l2-relayd-ipu6`, the service that feeds the IPU6 camera into the /dev/video60 loopback.";
      }
      {
        command = [
          "settings"
          "webcam"
          "restart"
        ];
        title = "Restart the IPU6 webcam relay";
        script = pkgs.writeShellScript "webcam-restart.sh" ''
          set -euo pipefail
          sudo systemctl restart v4l2-relayd-ipu6.service
          systemctl status v4l2-relayd-ipu6.service --no-pager -n 5
        '';
        usage = "Restarts `v4l2-relayd-ipu6` when the camera shows black or apps can't open it. Requires sudo.";
      }
    ];
  };
}
