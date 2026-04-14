{
  config,
  lib,
  pkgs,
  ...
}:
let
  adminUser = config.skynet.host.adminUser;
in
{
  config = lib.mkIf config.skynet.module.projects.andamp.CEIFRS {
    services.guacamole-server = {
      enable = false;
      host = "127.0.0.1";
    };

    services.guacamole-client = {
      enable = false;
      enableWebserver = false;
      settings = {
        guacd-port = 4822;
        guacd-hostname = "127.0.0.1";
      };
    };

    security.sudo.extraRules = lib.mkIf (adminUser != null) [
      {
        users = [ adminUser ];
        commands = [
          {
            command = "${pkgs.coreutils}/bin/cp * /etc/guacamole/user-mapping.xml";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${pkgs.coreutils}/bin/chown tomcat\\:tomcat /etc/guacamole/user-mapping.xml";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${pkgs.coreutils}/bin/chmod 0400 /etc/guacamole/user-mapping.xml";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
