{ config, lib, ... }:
{
  config = lib.mkIf config.skynet.module.assorted.avahi.enable {
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
  };
}
