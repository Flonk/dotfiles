{ config, pkgs, ... }:
{
  imports = [
    ../../../config/types
    ./schnitzelwirt-hardware.nix
    ./schnitzelwirt-hostconfig.nix
    ../common.nix
    ../../../home/modules/work/andamp-host.nix
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
    open = false; # switch off the open module
    modesetting.enable = true;
    powerManagement.enable = true; # NVreg_DynamicPowerManagement=0x02 + nvidia-powerd
    prime = {
      offload.enable = true; # iGPU drives display; dGPU only on demand
      offload.enableOffloadCmd = true; # sets up __NV_PRIME_RENDER_OFFLOAD=1 etc.
      intelBusId = "PCI:0:2:0"; # from lspci: 00:02.0
      nvidiaBusId = "PCI:1:0:0"; # from lspci: 01:00.0
    };
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Hardware graphics acceleration
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      libva-vdpau-driver
      libvdpau-va-gl
      nvidia-vaapi-driver
    ];
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    NIXOS_OZONE_WL = "1";
    GSK_RENDERER = "cairo";
  };

  environment.variables = {
    GSK_RENDERER = "cairo";
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
      "libvirtd"
      "kvm"
    ];
  };

  services.thinkfan.enable = true;

  # whitelist Google Pixel 9
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ENV{DEVNAME}=="/dev/bus/usb/*", ATTR{idVendor}=="18d1", ATTR{idProduct}=="4ee7", MODE="0664", GROUP="plugdev"
  '';

  services.greetd.settings.default_session.user = "flo";
  programs.steam.enable = true;

  programs.nix-ld.enable = true;
  # 1) Libvirt (QEMU/KVM) + UEFI firmware
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      swtpm.enable = true; # TPM 2.0 (some guests expect it)
    };
  };

  # 2) GUI manager
  programs.virt-manager.enable = true;

  # (optional) Autostart the default NAT network
  systemd.services."virtnetwork@default".wantedBy = [ "multi-user.target" ];

}
