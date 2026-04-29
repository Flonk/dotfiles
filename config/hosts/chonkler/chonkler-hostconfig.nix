{ ... }:
{
  config.skynet = {
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
        easyeffects = {
          db = ./cache/easyeffects/db;
          speakerSink = "alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__Speaker__sink";
        };
        stylix.enable = true;
        wireplumber.enable = true;
      };
      development = {
        dnsmasq.enable = true;
        qemu.enable = true;
      };
      leisure = {
        "gopro-webcam".enable = true;
      };
      os = {
        fingerprint.enable = false;
        # IPU6 webcam — currently broken due to SVP7500 USB-IO bridge bulk
        # transfer bugs (intel/ipu6-drivers#426), but keep enabled so it
        # starts working automatically when upstream fixes land.
        ipu6 = {
          enable = true;
          platform = "ipu6epmtl";
        };
        greetd = {
          enable = true;
          greeter = "none";
        };
        grub.enable = true;
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
