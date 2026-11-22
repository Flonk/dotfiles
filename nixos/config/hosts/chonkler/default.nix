{
  config,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = [ pkgs.foot ];
  services.fwupd.enable = true;

  imports = [
    ../../../types
    ../common.nix
    ./chonkler-system.nix
    ./chonkler-hardware.nix
    ./chonkler-hostconfig.nix
  ];

  boot.loader.grub.efiSupport = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.devices = [ "nodev" ];
  boot.loader.grub.configurationLimit = 20;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.initrd.kernelModules = [ "xe" ];
  boot.blacklistedKernelModules = [ "i915" ];
  boot.kernelParams = [
    "xe.force_probe=7d51"
    "i915.force_probe=!7d51"
    "printk.always_kmsg_dump"
    "nmi_watchdog=1"
  ];

  boot.kernel.sysctl = {
    "kernel.panic" = 20;
    "kernel.panic_on_oops" = 1;
    "kernel.softlockup_panic" = 1;
    "kernel.hardlockup_panic" = 1;
  };
  systemd.tmpfiles.rules = [ "w /sys/power/pm_debug_messages - - - - 1" ];
  powerManagement.powerDownCommands = ''
    export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.gnugrep ]}:$PATH
    dgpu=$(cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status 2>/dev/null)
    ac=$(cat /sys/class/power_supply/AC/online 2>/dev/null)
    bat=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
    outs=$(grep -l '^connected' /sys/class/drm/card*-*/status 2>/dev/null | cut -d/ -f5 | tr '\n' ' ')
    ${pkgs.util-linux}/bin/logger -t suspend-forensics "dgpu=$dgpu ac=$ac bat=$bat outputs=$outs"
    ${config.systemd.package}/bin/journalctl --sync
    sync
  '';
  boot.kernelModules = [
  ];

  boot.extraModprobeConfig = "options nvidia-drm modeset=1";
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    powerManagement.enable = true;
    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      libva-vdpau-driver
      libvdpau-va-gl
      nvidia-vaapi-driver
    ];
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    GSK_RENDERER = "cairo";
  };

  environment.variables = {
    GSK_RENDERER = "cairo";
  };

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

  services.greetd.settings.default_session.user = lib.mkDefault "flo";
  programs.steam.enable = true;

  programs.nix-ld.enable = true;
}
