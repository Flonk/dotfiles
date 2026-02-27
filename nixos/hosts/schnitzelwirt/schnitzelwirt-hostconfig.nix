{ ... }:
{
  config.skynet = {
    primaryMonitor = {
      width = 1920;
      height = 1080;
      hz = 60;
    };

    module.system = {
      avahi = false;
      chrome-remote-desktop = false;
      dnsmasq = true;
      fingerprint = true;
      greetd = true;
      grub = true;
      ollama = true;
      powersaver = true;
      qemu = true;
    };

    module.work.andamp = {
      enabled = true;
      CEFKM = true;
    };
  };
}
