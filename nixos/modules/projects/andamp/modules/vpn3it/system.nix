{
  config,
  lib,
  pkgs,
  ...
}:
let
  adminUser = config.skynet.host.adminUser;
  ip = "${pkgs.iproute2}/bin/ip";
in
{
  config =
    lib.mkIf (config.skynet.module.projects.andamp.CEFKM || config.skynet.module.projects.andamp.CEIFRS)
      {
        sops = {
          secrets."vpn3itdnsmasq" = {
            path = "/etc/dnsmasq.d/vpn3it.conf";
            sopsFile = ./secrets/secrets.json;
          };
        };

        services.dnsmasq = {
          settings.conf-file = config.sops.secrets."vpn3itdnsmasq".path;
        };

        security.sudo.extraRules = lib.mkIf (adminUser != null) [
          {
            users = [ adminUser ];
            commands = [
              {
                command = "${ip} route del *";
                options = [ "NOPASSWD" ];
              }
              {
                command = "${ip} route replace *";
                options = [ "NOPASSWD" ];
              }
              {
                command = "${pkgs.openconnect}/bin/openconnect *";
                options = [ "NOPASSWD" ];
              }
              {
                command = "${pkgs.procps}/bin/pkill -SIGINT openconnect";
                options = [ "NOPASSWD" ];
              }
            ];
          }
        ];
      };
}
