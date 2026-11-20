{ config, lib, ... }:
{
  config = lib.mkIf config.skynet.module.core.eventbus.enable {
    services.mosquitto = {
      enable = true;
      listeners = [
        {
          address = "127.0.0.1";
          port = 1883;
          omitPasswordAuth = true;
          acl = [ "topic readwrite #" ];
          settings.allow_anonymous = true;
        }
      ];
    };
  };
}
