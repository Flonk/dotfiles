{ lib, config, ... }:
{
  sops.secrets.vpn3itdnsmasq = {
    sopsFile = ../../../assets/secrets/secrets.json;
    key = "vpn3itdnsmasq";
  };

  services.dnsmasq.settings."conf-file" = lib.mkAfter [ config.sops.secrets.vpn3itdnsmasq.path ];
}
