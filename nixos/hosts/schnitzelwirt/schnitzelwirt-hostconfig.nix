{ ... }:
{
  config.skynet = {
    primaryMonitor = {
      width = 1920;
      height = 1080;
      hz = 60;
    };

    module.system = {
      dnsmasq = true;
      fingerprint = true;
      greetd = true;
      powersaver = true;
      qemu = true;
    };

    module.work.andamp = {
      enabled = true;
      CEFKM = true;
    };
  };
}
