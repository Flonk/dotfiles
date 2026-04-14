{
  config,
  lib,
  pkgs,
  ...
}:
let
  adminUser = config.skynet.host.adminUser;
  authorizedKeys = config.skynet.host.ssh.authorizedKeys;
in
{
  imports = [
    ../../modules/assorted/avahi/system.nix
    ../../modules/assorted/chrome-remote-desktop/system.nix
    ../../modules/desktop/hyprland/system.nix
    ../../modules/desktop/stylix/system.nix
    ../../modules/development/dnsmasq/system.nix
    ../../modules/development/qemu/system.nix
    ../../modules/os/fingerprint/system.nix
    ../../modules/os/greetd/system.nix
    ../../modules/os/grub/system.nix
    ../../modules/os/powersaver/system.nix
    ../../modules/projects/andamp/CEFKM/system.nix
    ../../modules/projects/andamp/modules/vpn3it/system.nix
  ];

  config = lib.mkMerge [
    {
      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];

      environment.systemPackages = with pkgs; [
        home-manager

        git
        micro

        curl
        wget

        foot

        iproute2
        nettools
        bind
        iputils
        nmap
        whois
      ];
    }
    (lib.mkIf (adminUser != null && authorizedKeys != [ ]) {
      users.users.${adminUser}.openssh.authorizedKeys.keys = authorizedKeys;
    })
  ];

}
