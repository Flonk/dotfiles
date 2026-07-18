{ lib, ... }:
{
  options.skynet.module.desktop.hyprland.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };
}
