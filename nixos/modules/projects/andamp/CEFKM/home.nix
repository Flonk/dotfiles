{
  config,
  lib,
  ...
}:
{
  imports = [
    ./insomnia.nix
  ];

  config = lib.mkIf config.skynet.module.projects.andamp.CEFKM {
  };
}
