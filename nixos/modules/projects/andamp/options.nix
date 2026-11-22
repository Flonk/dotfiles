{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.projects.andamp = {
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
    crdpBackend = mkOption {
      type = types.enum [
        "xephyr"
        "xvfb"
      ];
      default = "xephyr";
    };
    doubletunnel = mkOption {
      type = types.bool;
      default = false;
    };
  };
}
