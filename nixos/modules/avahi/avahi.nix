{ config, lib, ... }:
{
  config = lib.mkIf config.skynet.module.system.avahi {
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
  };
}
