{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.skynet.module.projects.personal.dwain.enable {
    home.packages = [
      pkgs.dotnet-sdk
      pkgs.unityhub
    ];
  };
}
