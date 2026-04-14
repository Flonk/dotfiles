{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.projects.andamp.CEIFRS {
    services.guacamole-client = {
      enable = true;
      enableWebserver = true;
      settings = {
        guacd-port = 4822;
        guacd-hostname = "127.0.0.1";
      };
    };
  };
}
