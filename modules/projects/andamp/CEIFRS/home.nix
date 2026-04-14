{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.skynet.module.projects.andamp.CEIFRS {
    home.packages = with pkgs; [
      freerdp
      tigervnc
      remmina
    ];
  };
}
