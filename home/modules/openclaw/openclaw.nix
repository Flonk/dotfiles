{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.home.openclaw {
    programs.openclaw = {
      enable = true;
    };
  };
}
