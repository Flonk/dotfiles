{ ... }:
{
  config.skynet = {
    whoami.host = "chonkler";
    host = {
      adminUser = "flo";
      motd.command = "fortune | cowsay";

      primaryMonitor = {
        width = 1920;
        height = 1200;
        hz = 60;
      };
    };

    module = {
      assorted = {
        avahi.enable = false;
      };
      desktop = {
        audio = {
          enable = true;
          defaultAudioSink = "alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__Speaker__sink";
          headphoneSink = "alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__Headphones__sink";
          easyeffects = {
            enable = true;
            db = ./cache/easyeffects/db;
          };
        };
        gloxwald.enable = true;
        hyprland.enable = true;
        stylix.enable = true;
      };
      development = {
        dnsmasq.enable = true;
        qemu.enable = true;
      };
      leisure = {
        "gopro-webcam".enable = true;
      };
      os = {
        # IPU6 webcam — re-enabled 2026-07-04 with out-of-tree intel_cvs +
        # DWC PHY fix (see obsidian://claude/video-setup).
        ipu6.enable = true;
        memory-pressure.enable = true;
        powersaver.enable = true;
      };
      projects = {
        andamp = {
          enable = true;
          CEFKM = true;
          CEIFRS = true;
        };
      };
    };
  };
}
