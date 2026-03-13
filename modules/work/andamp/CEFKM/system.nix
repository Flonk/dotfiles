{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.work.andamp.CEFKM {
    sops = {
      secrets."vpn3itdnsmasq" = {
        path = "/etc/dnsmasq.d/vpn3it.conf";
        sopsFile = ./secrets/secrets.json;
      };
    };

    services.dnsmasq = {
      settings.conf-file = config.sops.secrets."vpn3itdnsmasq".path;
    };

    security.pki.certificateFiles = [
      ./certs/ROOTCA2020.crt
      ./certs/obk-dev.crt
      ./certs/obk-int-server.crt
    ];
  };
}
