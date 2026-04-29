{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.leisure."gopro-webcam" = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open UDP port 8554 for the GoPro stream";
    };
    startOnBoot = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically start the gopro-webcam service at boot (requires GoPro to be connected and powered on)";
    };
    autoStart = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically start/stop webcam when GoPro is plugged/unplugged via USB";
    };
  };
}
