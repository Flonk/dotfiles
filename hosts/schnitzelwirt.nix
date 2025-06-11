{ config, pkgs, ... }: {
  imports =
    [
      ./schnitzelwirt-hardware.nix
      ./common.nix
    ];

  networking.hostName = "schnitzelwirt";

  # Bootloader config
  boot.loader.grub.efiSupport = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.devices = [ "nodev" ];

  boot.initrd.kernelModules = [ "i915" ];
  boot.kernelModules = [ "i915" "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  boot.extraModprobeConfig = "options nvidia-drm modeset=1";
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
  	modesetting.enable = true;
  	package = config.boot.kernelPackages.nvidiaPackages.stable;
  	open = true;
  };

  virtualisation.docker.enable = true;
}
