{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.skynet.module.os.ipu6;
in
{
  config = lib.mkIf cfg.enable {
    hardware.ipu6 = {
      enable = true;
      platform = cfg.platform;
    };
  };
}
