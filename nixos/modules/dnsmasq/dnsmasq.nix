{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.system.dnsmasq {
    services.dnsmasq = {
      enable = true;
      settings = {
        listen-address = "127.0.0.1";
        bind-interfaces = true;
        no-resolv = true;

        server = [
          "1.1.1.1"
          "8.8.8.8"
        ];

        # (i.e., DON'T set domain-needed=true)
        bogus-priv = true;
        cache-size = 1000;
      };
    };
  };
}
