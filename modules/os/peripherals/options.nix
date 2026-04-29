{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.os.peripherals = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    trustedDevices = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            mac = mkOption {
              type = types.str;
              description = "Bluetooth MAC address, e.g. AA:BB:CC:DD:EE:FF";
            };
            description = mkOption {
              type = types.str;
              default = "";
              description = "Human-readable label for this device";
            };
          };
        }
      );
      default = [ ];
      description = "Bluetooth devices to auto-trust so they never trigger authorization prompts";
    };
  };
}
