{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.skynet.module.os.memory-pressure;
in
{
  config = lib.mkIf cfg.enable {
    # zram: compressed RAM-backed swap. ~5 GB/s vs ~200 MB/s for NVMe swap,
    # so swap-in never bottlenecks the CPU. Default priority is higher than
    # the on-disk swap, so zram fills first and disk swap stays as a cold
    # fallback. See obsidian://claude/video-setup.
    zramSwap = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = cfg.zramPercent;
    };

    # systemd-oomd: kill the worst memory hog before swap thrashing freezes
    # the system. enableUserSlices wires ManagedOOMMemoryPressure=kill onto
    # the per-user slice so chromium/electron leaks get caught proactively.
    systemd.oomd = {
      enable = true;
      enableRootSlice = true;
      enableSystemSlice = false;
      enableUserSlices = true;
      settings.OOM = {
        DefaultMemoryPressureLimit = "60%";
        DefaultMemoryPressureDurationSec = "20s";
      };
    };

    # Kernel VM tunables. Values match Fedora's zram defaults — high
    # swappiness because zram is fast, page-cluster=0 because zram doesn't
    # benefit from readahead, higher watermark_scale_factor so reclaim
    # starts earlier (giving oomd time to react before pages hit disk swap).
    boot.kernel.sysctl = {
      "vm.swappiness" = lib.mkDefault 180;
      "vm.watermark_boost_factor" = lib.mkDefault 0;
      "vm.watermark_scale_factor" = lib.mkDefault 125;
      "vm.page-cluster" = lib.mkDefault 0;
    };

    # memwatch: samples per-actor memory metrics to a persistent TSV so the
    # post-call OOM explosion can be diagnosed from the time series after a
    # forced reboot. OOMScoreAdjust=-1000 keeps the sampler itself alive
    # while everything else thrashes. See obsidian://claude/video-setup.
    systemd.services.skynet-memwatch = lib.mkIf cfg.memwatch {
      description = "Aggregated memory metrics sampler (post-call OOM debugging)";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.bash}/bin/bash ${./memwatch.sh} daemon";
        Restart = "always";
        RestartSec = "2s";
        Nice = -5;
        OOMScoreAdjust = -1000;
        LogsDirectory = "skynet-memwatch";
        Environment = [ "MEMWATCH_INTERVAL=${toString cfg.memwatchInterval}" ];
        # Cap stop time so the sampler can't ever wedge shutdown.
        TimeoutStopSec = "3s";
        KillMode = "mixed";
      };
      path = [
        pkgs.coreutils
        pkgs.procps
        pkgs.gawk
        pkgs.findutils
      ];
    };
  };
}
