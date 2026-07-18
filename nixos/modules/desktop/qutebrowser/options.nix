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

    memoryMax = mkOption {
      type = types.str;
      default = "11G";
      description = "Hard memory limit for the qutebrowser scope — the cgroup OOM-killer kills qutebrowser past this.";
    };
  };
}
