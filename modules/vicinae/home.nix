{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.vicinae.enable {
    services.vicinae = {
      enable = true;

      package = pkgs.vicinae;

      systemd = {
        enable = true;
        autoStart = true;
        target = "graphical-session.target";
      };
    };
  };
}
