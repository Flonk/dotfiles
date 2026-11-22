{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.ai."claude-code" = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    service.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable the claude-remote-control systemd user service.";
    };
    service.models = mkOption {
      type = types.listOf types.str;
      default = [
        "haiku"
        "sonnet"
        "opus"
      ];
    };
  };
}
