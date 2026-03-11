{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../types
    ../common.nix
    ./hetzy-hardware.nix
    ./hetzy-hostconfig.nix
  ];

  networking.hostName = "hetzy";
  networking.useDHCP = lib.mkDefault true;

  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.devices = [ "nodev" ];
  boot.loader.efi.canTouchEfiVariables = true;

  services.openssh.enable = true;
  services.openssh.openFirewall = true;
  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };
  services.xserver.enable = false;
  programs.hyprland.enable = false;
  services.displayManager.autoLogin.enable = false;

  users.users.zeroclaw = {
    isNormalUser = true;
    description = "zeroclaw";
    extraGroups = [
      "wheel"
    ];
  };

  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  system.stateVersion = "25.05";
}
