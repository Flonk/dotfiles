{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.powersaver.enable {
    services.upower.enable = true;

    ############################################
    # Core power-saving services (system level)
    ############################################
    services.tlp.enable = true;
    services.tlp.settings = {
      # CPU - powersave governor dynamically scales frequency based on load
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";

      CPU_BOOST_ON_BAT = "0";

      # Platform profile (if supported by your hardware)
      PLATFORM_PROFILE_ON_AC = "low-power";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      # Fan control
      FAN_SPEED_ON_AC = "auto";
      FAN_SPEED_ON_BAT = "auto";

      # PCIe link power management
      PCIE_ASPM_ON_AC = "powersupersave";
      PCIE_ASPM_ON_BAT = "powersupersave";

      # USB autosuspend
      USB_AUTOSUSPEND = 1;

      # Wi-Fi power save
      WIFI_PWR_ON_BAT = "on";

      # AMD/ATI knobs (harmless if not present)
      RADEON_POWER_PROFILE_ON_BAT = "low";
      RADEON_DPM_STATE_ON_BAT = "battery";

      RUNTIME_PM_ON_AC = "auto";
      RUNTIME_PM_ON_BAT = "auto";
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
  };
}
