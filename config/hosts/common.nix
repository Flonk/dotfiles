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
    ../../modules/desktop/audio/system.nix
    ../../modules/development/dnsmasq/system.nix
    ../../modules/development/qemu/system.nix
    ../../modules/leisure/gopro-webcam/system.nix
    ../../modules/desktop/skynetshell/system.nix
    ../../modules/os/ipu6/system.nix
    ../../modules/os/grub/system.nix
    ../../modules/os/powersaver/system.nix
    ../../modules/projects/andamp/CEFKM/system.nix
    ../../modules/projects/andamp/CEIFRS/system.nix
    ../../modules/projects/andamp/modules/vpn3it/system.nix
  ];

  config = lib.mkMerge [
    {
      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        max-jobs = "auto";
        cores = 0;
        substituters = [
          "https://nix-community.cachix.org"
        ];
        trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
      };

      environment.systemPackages = with pkgs; [
        home-manager

        git
        micro

        curl
        wget

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
