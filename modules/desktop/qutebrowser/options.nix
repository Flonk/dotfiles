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
    # memory on WebRTC call teardown (see obsidian://claude/video-setup),
    # freezing the whole laptop. The package is launched inside a transient
    # systemd scope with these limits so a leak kills qutebrowser, not the
    # machine. MemoryHigh throttles (soft), MemoryMax hard-kills via the
    # cgroup OOM-killer.
    memoryHigh = mkOption {
      type = types.str;
      default = "10G";
      description = "Soft memory limit for the qutebrowser scope — the kernel throttles allocation past this.";
    };
    memoryMax = mkOption {
      type = types.str;
      default = "11G";
      description = "Hard memory limit for the qutebrowser scope — the cgroup OOM-killer kills qutebrowser past this.";
    };
  };
}
