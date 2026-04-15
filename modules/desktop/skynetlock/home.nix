{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.desktop.skynetlock.enable {
    programs.skynetlock = {
      enable = true;
      theme = config.skynet.module.desktop.skynetlock.theme;
      daemon.enable = true;
    };
  };
}
