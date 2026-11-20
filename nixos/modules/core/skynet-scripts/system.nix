{
  config,
  lib,
  ...
}:
let
  adminUser = config.skynet.host.adminUser;
in
{
  config = lib.mkIf (adminUser != null) {
    security.sudo.extraRules = [
      {
        users = [ adminUser ];
        commands = [
          {
            command = "/run/current-system/sw/bin/nixos-rebuild switch --no-reexec --flake ${
              config.users.users.${adminUser}.home
            }/repos/personal/dotfiles/nixos";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
