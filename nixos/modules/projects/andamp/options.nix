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
    crdpPackage = mkOption {
      type = types.nullOr types.package;
      default = null;
      internal = true;
    };
    vpn3itPriority = mkOption {
      type = types.bool;
      default = false;
      description = "This installation wins the 3it VPN: it asks other hosts holding it to release instead of refusing to connect.";
    };
  };
}
