{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.t3os.module.os.ipu6;
in
{
  config = lib.mkIf cfg.enable {
    hardware.ipu6 = {
      enable = true;
      platform = cfg.platform;
      videoDeviceNumber = 60;
    };

    boot.kernelModules = [ "intel_cvs" ];

    nixpkgs.overlays = [
      (final: prev: {
        ipu6epmtl-camera-hal = prev.ipu6epmtl-camera-hal.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ./hal-ov08x40-cvs.patch ];
        });
      })
    ];

    systemd.services.v4l2-relayd-ipu6 = {
      environment = {
        GST_REGISTRY = "/run/v4l2-relayd-ipu6/gst-registry.bin";
        GST_DEBUG = "2,icamerasrc:5";
        GST_DEBUG_NO_COLOR = "1";
      };
      startLimitIntervalSec = 0;
      serviceConfig = {
        RestartSec = lib.mkForce 5;
        # The IPU6 driver historically wedged in D-state on shutdown; keep the
        # stop path short — see obsidian://claude/video-setup.
        TimeoutStopSec = lib.mkForce "1s";
        KillSignal = lib.mkForce "SIGKILL";
        PrivateTmp = lib.mkForce false;
        ExecStartPre = [ "-${pkgs.util-linux}/bin/ipcrm -M 0x0043414d" ];
      };
    };
  };
}
