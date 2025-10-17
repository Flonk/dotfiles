{ pkgs, ... }:
{
  home.packages = with pkgs; [
    powertop
    tlp
    thermald
  ];

  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      PCIE_ASPM_ON_BAT = "powersupersave";
      RADEON_POWER_PROFILE_ON_BAT = "low";
      RADEON_DPM_STATE_ON_BAT = "battery";
      USB_AUTOSUSPEND = 1;
      WIFI_PWR_ON_BAT = "on";
    };
  };

  services.thermald.enable = true;

  systemd.user.services.powertop = {
    Unit.Description = "Powertop auto-tune (user)";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.powertop}/bin/powertop --auto-tune";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
