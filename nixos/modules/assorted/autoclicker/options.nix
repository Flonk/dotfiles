{ lib, ... }:
{
  options.t3os.module.assorted.autoclicker.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };
}
