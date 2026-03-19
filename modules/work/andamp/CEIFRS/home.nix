{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.skynet.module.work.andamp.CEIFRS {
    home.packages = with pkgs; [
      freerdp
      tigervnc
    ];
  };
}
