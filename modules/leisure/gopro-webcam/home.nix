{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.skynet.module.leisure."gopro-webcam";

  startScript = pkgs.writeShellScript "gopro-start.sh" ''
    exec gopro-webcam start "$@"
  '';

  stopScript = pkgs.writeShellScript "gopro-stop.sh" ''
    exec gopro-webcam stop "$@"
  '';
in
{
  config = lib.mkIf cfg.enable {
    skynet.cli.scripts = [
      {
        command = [
          "gopro"
          "start"
        ];
        title = "Start GoPro webcam";
        script = startScript;
        usage = "Puts the GoPro into webcam mode and starts ffmpeg publishing to a v4l2loopback device. Optional args: [1080|720|480] [linear|wide|narrow|superview].";
      }
      {
        command = [
          "gopro"
          "stop"
        ];
        title = "Stop GoPro webcam";
        script = stopScript;
        usage = "Stops ffmpeg and unloads v4l2loopback.";
      }
    ];
  };
}
