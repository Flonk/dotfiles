{ config, pkgs, ... }:
{
  imports = [
    ./schnitzelwirt-hardware.nix
    ./common.nix
  ];

  networking.hostName = "schnitzelwirt";

  # Bootloader config
  boot.loader.grub.efiSupport = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.devices = [ "nodev" ];

  boot.initrd.kernelModules = [ "i915" ];
  boot.kernelModules = [
    "i915"
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
    "usb"
    "btusb"
    "bluetooth"
  ];
  boot.extraModprobeConfig = "options nvidia-drm modeset=1";
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    open = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.flo = {
    isNormalUser = true;
    description = "flo";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
  };

  services.greetd.settings.default_session.user = "flo";

  programs.steam.enable = true;
}
