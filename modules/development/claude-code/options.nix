{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.development."claude-code" = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    service.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable the claude-remote-control systemd user service.";
    };
  };
}
