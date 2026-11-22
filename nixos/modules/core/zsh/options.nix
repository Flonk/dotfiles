{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.core.zsh.enable = mkOption {
    type = types.bool;
    default = true;
  };
}
