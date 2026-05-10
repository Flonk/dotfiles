{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.core.zsh.enable = mkOption {
    type = types.bool;
    default = true;
  };
}
