{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.desktop.qutebrowser = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };

    softwareVideoDecode = mkOption {
      type = types.bool;
      default = false;
      description = "Launch qutebrowser with --disable-accelerated-video-decode (leak experiment, 2026-07-12).";
    };

    pinToIgpu = mkOption {
      type = types.bool;
      default = true;
      description = "Restrict qutebrowser's EGL/GLX vendor to Mesa so it never touches the dGPU (crash experiment, 2026-08-13).";
    };

    disableGpuMemoryBufferVideoFrames = mkOption {
      type = types.bool;
      default = false;
      description = "Launch qutebrowser with --disable-gpu-memory-buffer-video-frames (screenshare-teardown crash, 2026-08-13).";
    };

    softwareCompositing = mkOption {
      type = types.bool;
      default = false;
      description = "Launch qutebrowser with --disable-gpu-compositing (screenshare-teardown hang, 2026-08-13).";
    };

    memoryMax = mkOption {
      type = types.str;
      default = "11G";
      description = "Hard memory limit for the qutebrowser scope — the cgroup OOM-killer kills qutebrowser past this.";
    };
  };
}
