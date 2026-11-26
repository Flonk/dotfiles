{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.t3os.module.development.lean.enable {
    home.packages = [ pkgs.elan ];
  };
}
