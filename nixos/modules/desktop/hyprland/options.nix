{ lib, ... }:
{
  options.t3os.module.desktop.hyprland.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };
}
