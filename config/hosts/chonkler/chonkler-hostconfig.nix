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
        "chrome-remote-desktop".enable = false;
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
        skynetshell.enable = true;
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
        # IPU6 webcam — disabled. Built-in camera is unusable due to
        # intel/ipu6-drivers#426 (SVP7500 USB-IO bridge bulk transfer bugs)
        # and the v4l2-relayd service it spawns wedges in D-state on every
        # shutdown (see obsidian://claude/video-setup). Re-enable when
        # upstream lands a fix.
        ipu6.enable = false;
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
