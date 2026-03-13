{ config, lib, ... }:
{
  # I added this so I can use my android phone as a MIDI input device.
  config = lib.mkIf config.skynet.module.assorted.avahi.enable {
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
  };
}
