{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.os.memory-pressure = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "zram swap, systemd-oomd policy, and PSI-aware kernel tuning. Prevents the desktop from freezing under memory pressure caused by leaky browser/Electron apps.";
    };

    zramPercent = mkOption {
      type = types.int;
      default = 50;
      description = "Percent of RAM to allocate as zram swap. 50% with zstd typically yields ~3x effective capacity.";
    };

    memwatch = mkOption {
      type = types.bool;
      default = true;
      description = "Run the t3os-memwatch daemon: samples per-actor memory metrics to /var/log/t3os-memwatch/metrics.tsv for debugging the post-call OOM explosion. Disable once that bug is resolved.";
    };

    memwatchInterval = mkOption {
      type = types.int;
      default = 5;
      description = "Seconds between memwatch samples. Drops to 1s automatically while MemAvailable is below 35% of RAM.";
    };
  };
}
