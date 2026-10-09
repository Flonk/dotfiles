{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.desktop.qutebrowser = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };

    # qutebrowser/QtWebEngine has leaked its main process to ~25G of anon
    # memory on WebRTC call teardown, freezing the whole laptop. The package
    # is launched inside a transient systemd scope with this limit so a leak
    # kills qutebrowser, not the machine. Hard cap only — no MemoryHigh: a
    # leak can't shed memory under pressure, so a soft limit just pins a core
    # in direct reclaim (frozen UI, stalled page loads) until the hard cap
    # kills it anyway.
    # Root-cause experiment for the WebRTC-teardown leak (see vault doc
    # claude/video-setup.md): force software video decode to test whether the
    # leak lives in the experimental Xe/iHD hardware-decode path. Costs ~1-2
    # cores during calls. No leak on the next Meet call => hardware path is
    # the culprit (keep this on); still leaks => upstream Chromium bug.
    softwareVideoDecode = mkOption {
      type = types.bool;
      default = true;
      description = "Launch qutebrowser with --disable-accelerated-video-decode (leak experiment, 2026-07-12).";
    };

    # glvnd ranks 10_nvidia.json above 50_mesa.json, so QtWebEngine initialises
    # NVIDIA EGL and holds /dev/nvidia0 + renderD129 open while rendering on the
    # Intel iGPU (renderD128). Restricting the vendor list to Mesa keeps the
    # browser off the dGPU entirely (crash experiment, see claude/video-setup.md).
    pinToIgpu = mkOption {
      type = types.bool;
      default = true;
      description = "Restrict qutebrowser's EGL/GLX vendor to Mesa so it never touches the dGPU (crash experiment, 2026-08-13).";
    };

    # Screencast frames arrive as dmabuf-backed GpuMemoryBuffers wrapped in
    # gpu::CompoundImageBacking. Tearing a screenshare down destroys them and
    # trips a NOTREACHED in SharedImageManager::OnRepresentationDestroyed,
    # which is fatal because QtWebEngine's GPU service is in-process. This
    # keeps capture/video frames off GpuMemoryBuffers entirely.
    # OFF since 2026-08-13: it did stop the abort, but pushing those frames into
    # CPU memory made teardown balloon the main process to the 11G cap twice in
    # a row — freeze via direct reclaim (Rule 9), then OOM kill. A survivable
    # abort with session restore beats a hang. Re-enable only with a fix for
    # the balloon.
    disableGpuMemoryBufferVideoFrames = mkOption {
      type = types.bool;
      default = false;
      description = "Launch qutebrowser with --disable-gpu-memory-buffer-video-frames (screenshare-teardown crash, 2026-08-13).";
    };

    # Takes the viz Display off SkiaOutputSurfaceImpl and onto a software output
    # surface. OFF by default: the "hang" it was meant to fix turned out to be
    # the memory balloon, not a GPU spin, and this flag pushes even more work
    # into CPU memory. Only worth trying once the balloon is understood.
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
