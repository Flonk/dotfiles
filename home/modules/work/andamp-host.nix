{ lib, config, ... }:
{
  sops.secrets.vpn3itdnsmasq = {
    sopsFile = ../../../assets/secrets/secrets.json;
    key = "vpn3itdnsmasq";
    owner = "dnsmasq";
    group = "dnsmasq";
    mode = "0440";
  };

  services.dnsmasq.settings."conf-file" = lib.mkAfter [ config.sops.secrets.vpn3itdnsmasq.path ];

  security.pki.certificateFiles = lib.mkAfter [
    ../../../assets/certs/obk-dev.crt
  ];
}
