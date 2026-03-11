{ ... }:
{
  config.skynet = {
    host = {
      adminUser = "flo";
    };

    primaryMonitor = {
      width = 1920;
      height = 1080;
      hz = 60;
    };

    module = {
      avahi.enable = false;
      chrome-remote-desktop.enable = false;
      dnsmasq.enable = true;
      fingerprint.enable = true;
      greetd = {
        enable = true;
        greeter = "none";
      };
      grub.enable = true;
      powersaver.enable = true;
      qemu.enable = true;

      andamp = {
        enable = true;
        CEFKM = true;
      };
    };
  };
}
