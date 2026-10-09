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
      # IPU6 raw nodes take video0-47 and USB webcams (dock) claim the next
      # free numbers, so 50 collides; GoPro sits at 61.
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
      # A failed icamerasrc load gets blacklisted in the gst registry cache
      # and nix store mtimes never invalidate it; keep the registry in /run
      # so every boot starts clean.
      environment = {
        GST_REGISTRY = "/run/v4l2-relayd-ipu6/gst-registry.bin";
        # v4l2-relayd tears the pipeline down before reporting, so a failed
        # start only logs GLib assertions; keep the real cause in the journal.
        GST_DEBUG = "2,icamerasrc:5";
        GST_DEBUG_NO_COLOR = "1";
      };
      # Don't stay dead for the whole session after early-boot failures.
      startLimitIntervalSec = 0;
      serviceConfig = {
        RestartSec = 5;
        # The IPU6 driver historically wedged in D-state on shutdown; keep the
        # stop path short — see obsidian://claude/video-setup.
        TimeoutStopSec = lib.mkForce "1s";
        KillSignal = lib.mkForce "SIGKILL";
        # CamHAL needs real /tmp and leaves a stale SysV shm segment behind.
        PrivateTmp = lib.mkForce false;
        ExecStartPre = [ "-${pkgs.util-linux}/bin/ipcrm -M 0x0043414d" ];
      };
    };
  };
}
