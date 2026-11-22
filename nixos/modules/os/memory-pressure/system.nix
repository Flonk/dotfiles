{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.t3os.module.os.memory-pressure;
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

    boot.kernel.sysctl = {
      "vm.swappiness" = lib.mkDefault 180;
      "vm.watermark_boost_factor" = lib.mkDefault 0;
      "vm.watermark_scale_factor" = lib.mkDefault 125;
      "vm.page-cluster" = lib.mkDefault 0;
    };
  };
}
