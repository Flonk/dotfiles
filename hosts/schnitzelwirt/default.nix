{ config, pkgs, ... }:
{
  imports = [
    ../../config/types
    ../../home/modules/work/andamp-host.nix
    ./schnitzelwirt-hardware.nix
    ./schnitzelwirt-hostconfig.nix
    ../common.nix
  ];

  networking.hostName = "schnitzelwirt";

  sops.age = {
    sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    keyFile = "/var/lib/sops-nix/key.txt";
    generateKey = true;
  };

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
      ovmf.enable = true; # UEFI firmware
      ovmf.packages = [ pkgs.OVMFFull.fd ];
    };
  };

  # 2) GUI manager
  programs.virt-manager.enable = true;

  # (optional) Autostart the default NAT network
  systemd.services."virtnetwork@default".wantedBy = [ "multi-user.target" ];

  services.dnsmasq = {
    enable = true;
    settings = {
      listen-address = "127.0.0.1";
      bind-interfaces = true;
      no-resolv = true;

      server = [
        "1.1.1.1"
        "8.8.8.8"
      ];

      # (i.e., DON'T set domain-needed=true)
      bogus-priv = true;
      cache-size = 1000;
    };
  };

}
