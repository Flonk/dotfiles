{ config, pkgs, ... }:
{
  imports = [
    ../../config/types
    ./schnitzelwirt-hardware.nix
    ./schnitzelwirt-hostconfig.nix
    ../common.nix
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

  # Hardware graphics acceleration
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      vaapiVdpau
      libvdpau-va-gl
      nvidia-vaapi-driver
    ];
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    NIXOS_OZONE_WL = "1";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.groups.plugdev = { };
  users.users.flo = {
    isNormalUser = true;
    description = "flo";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "plugdev"
    ];
  };

  # whitelist Google Pixel 9
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ENV{DEVNAME}=="/dev/bus/usb/*", ATTR{idVendor}=="18d1", ATTR{idProduct}=="4ee7", MODE="0664", GROUP="plugdev"
  '';

  services.greetd.settings.default_session.user = "flo";
  programs.steam.enable = true;
}
