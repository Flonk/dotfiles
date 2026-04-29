{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.desktop.skynetlock = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    theme = mkOption {
      type = types.str;
      default = "";
      description = "Shader theme for the lock screen (e.g. 'mobius_spiral'. Keep empty for random)";
    };
  };
}
