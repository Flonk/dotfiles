{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.t3os.module.leisure.lutris.enable {
    home.packages = with pkgs; [
      lutris
    ];
  };
}
