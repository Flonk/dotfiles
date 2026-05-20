{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.skynet.module.os.ipu6;
in
{
  config = lib.mkIf cfg.enable {
    hardware.ipu6 = {
      enable = true;
      platform = cfg.platform;
    };

    # The IPU6 driver (intel/ipu6-drivers#426) wedges GStreamer threads in
    # D-state on shutdown, making each stop phase burn the full 90s default.
    # Cap the timeout and skip SIGTERM since the broken pipeline can't handle
    # it anyway — see obsidian://claude/video-setup.
    systemd.services.v4l2-relayd-ipu6.serviceConfig = {
      TimeoutStopSec = lib.mkForce "1s";
      KillSignal = lib.mkForce "SIGKILL";
    };
  };
}
