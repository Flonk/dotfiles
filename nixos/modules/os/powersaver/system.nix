{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.os.powersaver.enable {
    services.upower.enable = true;

    services.tlp.enable = true;
    services.tlp.settings = {
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";

      CPU_BOOST_ON_BAT = "0";

      PLATFORM_PROFILE_ON_AC = "low-power";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      FAN_SPEED_ON_AC = "auto";
      FAN_SPEED_ON_BAT = "auto";

      PCIE_ASPM_ON_AC = "default";
      PCIE_ASPM_ON_BAT = "powersupersave";

      USB_AUTOSUSPEND = 0;

      WIFI_PWR_ON_BAT = "on";

      RADEON_POWER_PROFILE_ON_BAT = "low";
      RADEON_DPM_STATE_ON_BAT = "battery";

      RUNTIME_PM_ON_AC = "auto";
      RUNTIME_PM_ON_BAT = "auto";
    };

    services.thermald.enable = true;

    services.power-profiles-daemon.enable = lib.mkDefault false;

    powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

    environment.systemPackages = with pkgs; [
      tlp
    ];

  };
}
