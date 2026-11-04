{ config, lib, ... }:
{
  config = lib.mkIf config.skynet.module.assorted.autoclicker.enable {
    programs.ydotool.enable = true;
    users.users.${config.skynet.host.adminUser}.extraGroups = [ config.programs.ydotool.group ];
  };
}
