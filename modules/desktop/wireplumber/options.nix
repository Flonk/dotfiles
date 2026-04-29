{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.desktop.wireplumber = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    laptopSink = mkOption {
      type = types.str;
      default = "";
      description = "PulseAudio sink name for the laptop speakers (fallback when no BT device is connected).";
    };
  };
}
