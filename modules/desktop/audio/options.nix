{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.desktop.audio = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    defaultAudioSink = mkOption {
      type = types.str;
      default = "";
      description = "PulseAudio sink name for the laptop speakers (fallback when no BT device is connected).";
    };
    trustedBluetoothHeadsets = mkOption {
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
      description = "Bluetooth headsets to auto-trust so they connect without authorization prompts";
    };
    easyeffects = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
      db = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to the EasyEffects db directory to deploy into ~/.config/easyeffects/db/ on rebuild.";
      };
      speakerPreset = mkOption {
        type = types.str;
        default = "defaultSink";
        description = "EasyEffects output preset name to load when the speaker sink is active.";
      };
    };
  };
}
