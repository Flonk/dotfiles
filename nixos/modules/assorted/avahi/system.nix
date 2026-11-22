{ config, lib, ... }:
{
  config = lib.mkIf config.t3os.module.assorted.avahi.enable {
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
  };
}
