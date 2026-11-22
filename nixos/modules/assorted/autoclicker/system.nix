{ config, lib, ... }:
{
  config = lib.mkIf config.t3os.module.assorted.autoclicker.enable {
    programs.ydotool.enable = true;
    users.users.${config.t3os.host.adminUser}.extraGroups = [ config.programs.ydotool.group ];
  };
}
