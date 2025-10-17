{
  config,
  pkgs,
  lib,
  ...
}:
{
  ############################################
  # Core power-saving services (system level)
  ############################################
  services.tlp.enable = true;
  services.tlp.settings = {
    # CPU
    CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
    CPU_SCALING_GOVERNOR_ON_AC = "performance";

    # PCIe link power management
    PCIE_ASPM_ON_BAT = "powersupersave";

    # USB autosuspend
    USB_AUTOSUSPEND = 1;

    # Wi-Fi power save
    WIFI_PWR_ON_BAT = "on";

    # AMD/ATI knobs (harmless if not present)
    RADEON_POWER_PROFILE_ON_BAT = "low";
    RADEON_DPM_STATE_ON_BAT = "battery";
  };

  # Intel/AMD CPU thermal management
  services.thermald.enable = true;

  # If your system has power-profiles-daemon (e.g. via GNOME),
  # it conflicts with TLP — disable it.
  services.power-profiles-daemon.enable = lib.mkDefault false;

  # Set a conservative default governor system-wide
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  ############################################
  # Powertop tunables at boot (root)
  ############################################
  systemd.services.powertop-autotune = {
    description = "Powertop --auto-tune at boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.powertop}/bin/powertop --auto-tune";
    };
  };

  ############################################
  # Useful CLI tools
  ############################################
  environment.systemPackages = with pkgs; [
    powertop
    tlp
  ];

  ############################################
  # (Optional) NVIDIA hybrid offload to save battery
  # Uncomment + set correct PCI bus IDs if you have NVIDIA.
  #
  # hardware.nvidia.prime = {
  #   offload.enable = true;
  #   intelBusId  = "PCI:0:2:0";  # adjust: lspci | grep -E 'VGA|3D'
  #   nvidiaBusId = "PCI:1:0:0";  # adjust accordingly
  # };
  ############################################
}
