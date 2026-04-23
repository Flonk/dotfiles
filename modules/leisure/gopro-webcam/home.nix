{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.skynet.module.leisure."gopro-webcam";
  videoDeviceNumber = 48;
  videoDevicePath = "/dev/video${toString videoDeviceNumber}";

  rootStart = pkgs.writeShellScript "gopro-start-root.sh" ''
    set -euo pipefail

    PID_FILE=/run/gopro-webcam-ffmpeg.pid
    LOG_FILE=/tmp/gopro-webcam-ffmpeg.log
    RESOLUTION="''${1:-1080}"

    case "$RESOLUTION" in
      1080)
        GOPRO_RESOLUTION="1080"
        VIDEO_SIZE="1920x1080"
        ;;
      720)
        GOPRO_RESOLUTION="720"
        VIDEO_SIZE="1280x720"
        ;;
      480)
        GOPRO_RESOLUTION="720"
        VIDEO_SIZE="854x480"
        ;;
      *)
        echo "Usage: gopro-start-root.sh [1080|720|480]" >&2
        exit 1
        ;;
    esac

    if [[ -f "$PID_FILE" ]]; then
      kill "$(cat "$PID_FILE")" 2>/dev/null || true
      rm -f "$PID_FILE"
    fi

    ${pkgs.procps}/bin/pkill -f '${videoDevicePath}' 2>/dev/null || true

    # Let any previous ffmpeg producer exit fully before the gopro helper tries
    # to unload/reload v4l2loopback itself.
    for _ in 1 2 3 4 5; do
      if ! ${pkgs.procps}/bin/pgrep -f '${videoDevicePath}' >/dev/null 2>&1; then
        break
      fi
      ${pkgs.coreutils}/bin/sleep 1
    done

    /run/current-system/sw/bin/gopro webcam -n --video-number ${toString videoDeviceNumber} -r "$GOPRO_RESOLUTION"

    ${pkgs.coreutils}/bin/nohup ${pkgs.ffmpeg}/bin/ffmpeg \
      -nostdin \
      -threads 1 \
      -use_wallclock_as_timestamps 1 \
      -f mpegts \
      -fflags nobuffer \
      -flags low_delay \
      -analyzeduration 256k \
      -probesize 256k \
      -i 'udp://@0.0.0.0:8554?overrun_nonfatal=1&fifo_size=100000000&buffer_size=8388608' \
      -map 0:v:0 \
      -vf "scale=$VIDEO_SIZE,format=yuv420p" \
      -fps_mode passthrough \
      -pix_fmt yuv420p \
      -f v4l2 \
      -s "$VIDEO_SIZE" \
      ${videoDevicePath} \
      >"$LOG_FILE" 2>&1 < /dev/null &

    echo $! > "$PID_FILE"
    ${pkgs.coreutils}/bin/sleep 2

    if ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "ffmpeg failed to stay up. Last log lines:" >&2
      ${pkgs.coreutils}/bin/tail -40 "$LOG_FILE" >&2 || true
      exit 1
    fi
  '';

  rootStop = pkgs.writeShellScript "gopro-stop-root.sh" ''
    set -euo pipefail

    PID_FILE=/run/gopro-webcam-ffmpeg.pid

    if [[ -f "$PID_FILE" ]]; then
      kill "$(cat "$PID_FILE")" 2>/dev/null || true
      rm -f "$PID_FILE"
    fi

    ${pkgs.procps}/bin/pkill -f '${videoDevicePath}' 2>/dev/null || true

    for _ in 1 2 3 4 5; do
      if ! ${pkgs.procps}/bin/pgrep -f '${videoDevicePath}' >/dev/null 2>&1; then
        break
      fi
      ${pkgs.coreutils}/bin/sleep 1
    done

    ${pkgs.kmod}/bin/modprobe -rf v4l2loopback 2>/dev/null || true
  '';

  startScript = pkgs.writeShellScript "gopro-start.sh" ''
    set -euo pipefail

    RESOLUTION="''${1:-1080}"

    cleanup() {
      ${pkgs.systemd}/bin/systemctl --user start wireplumber >/dev/null 2>&1 || true
    }

    trap cleanup EXIT

    ${pkgs.systemd}/bin/systemctl --user stop wireplumber >/dev/null 2>&1 || true
    /run/wrappers/bin/sudo ${rootStart} "$RESOLUTION"

    echo "GoPro webcam started."
    echo "Video device: ${videoDevicePath}"
    echo "Resolution: $RESOLUTION"
    echo "FFmpeg log: /tmp/gopro-webcam-ffmpeg.log"
  '';

  stopScript = pkgs.writeShellScript "gopro-stop.sh" ''
    set -euo pipefail

    /run/wrappers/bin/sudo ${rootStop}
    ${pkgs.systemd}/bin/systemctl --user start wireplumber >/dev/null 2>&1 || true

    echo "GoPro webcam stopped."
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
        usage = "Stops wireplumber, puts the GoPro into webcam mode, and starts ffmpeg publishing to ${videoDevicePath}. Optional first argument: 1080, 720, or 480. On this setup, 480 uses the GoPro's 720 stream and scales it down locally because the camera rejects native 480p webcam mode.";
      }
      {
        command = [
          "gopro"
          "stop"
        ];
        title = "Stop GoPro webcam";
        script = stopScript;
        usage = "Stops the ffmpeg publisher, unloads v4l2loopback, and starts wireplumber again.";
      }
    ];
  };
}
