{ ... }:
{
  config.skynet = {
    host = {
      adminUser = "flo";
      motd.command = "fortune | cowsay";

      primaryMonitor = {
        width = 1920;
        height = 1080;
        hz = 60;
      };
    };

    module = {
      assorted = {
        avahi.enable = false;
        "chrome-remote-desktop".enable = false;
      };
      desktop = {
        stylix.enable = true;
      };
      development = {
        dnsmasq.enable = true;
        qemu.enable = true;
      };
      os = {
        greetd = {
          enable = true;
          greeter = "none";
        };
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
