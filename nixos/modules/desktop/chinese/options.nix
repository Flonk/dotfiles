{ lib, ... }:
{
  options.t3os.module.desktop.chinese.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };
}
