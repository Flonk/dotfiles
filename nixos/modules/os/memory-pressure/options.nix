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
  };
}
