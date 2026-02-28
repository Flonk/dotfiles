{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.andamp.CEFKM {
    sops = {
      secrets."vpn3itdnsmasq" = {
        path = "/etc/dnsmasq.d/vpn3it.conf";
        sopsFile = ../../../../assets/work/andamp/CEFKM/secrets/secrets.json;
      };
    };

    services.dnsmasq = {
      settings.conf-file = config.sops.secrets."vpn3itdnsmasq".path;
    };

    security.pki.certificateFiles = [
      ../../../../assets/work/andamp/CEFKM/certs/ROOTCA2020.crt
      ../../../../assets/work/andamp/CEFKM/certs/obk-dev.crt
      ../../../../assets/work/andamp/CEFKM/certs/obk-int-server.crt
    ];
  };
}
