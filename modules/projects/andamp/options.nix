{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.projects.andamp = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    CEFKM = mkOption {
      type = types.bool;
      default = false;
    };
    CEIFRS = mkOption {
      type = types.bool;
      default = false;
    };
  };
}
