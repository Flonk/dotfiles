{
  config,
  lib,
  ...
}:
let
  adminUser = config.skynet.host.adminUser;
  authorizedKeys = config.skynet.host.ssh.authorizedKeys;
in
{
  imports = [
    ../../modules/avahi/system.nix
    ../../modules/chrome-remote-desktop/system.nix
    ../../modules/dnsmasq/system.nix
    ../../modules/fingerprint/system.nix
    ../../modules/greetd/system.nix
    ../../modules/grub/system.nix
    ../../modules/powersaver/system.nix
    ../../modules/qemu/system.nix
    ../../modules/work/andamp/CEFKM/system.nix
  ];

  config = lib.mkIf (adminUser != null && authorizedKeys != [ ]) {
    users.users.${adminUser}.openssh.authorizedKeys.keys = authorizedKeys;
  };

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
