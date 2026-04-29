{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.desktop.easyeffects = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    db = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to the EasyEffects db directory to deploy into ~/.config/easyeffects/db/ on rebuild.";
    };
    speakerSink = mkOption {
      type = types.str;
      default = "";
      description = "PulseAudio sink name for the internal speakers. When this is the default sink, EasyEffects processes audio; otherwise it bypasses.";
    };
    speakerPreset = mkOption {
      type = types.str;
      default = "defaultSink";
      description = "EasyEffects output preset name to load when the speaker sink is active.";
    };
  };
}
