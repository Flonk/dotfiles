{
  config,
  lib,
  pkgs,
  ...
}:
let
  tlp = "/run/current-system/sw/bin/tlp";
  mode =
    name: arg:
    pkgs.writeShellScript "power-${name}.sh" ''
      set -euo pipefail
      exec sudo ${tlp} ${arg}
    '';
in
{
  config = lib.mkIf config.t3os.module.os.powersaver.enable {
    t3os.cli.scripts = [
      {
        command = [
          "settings"
          "power"
          "status"
        ];
        title = "Show battery, power source and CPU profile";
        script = pkgs.writeShellScript "power-status.sh" ''
          set -uo pipefail
          for bat in $(${pkgs.upower}/bin/upower -e | grep -E 'BAT|line_power'); do
            ${pkgs.upower}/bin/upower -i "$bat" | grep -E 'native-path|online|state|percentage|time to|energy-rate' | sed 's/^ */  /'
            echo
          done
          echo "  governor:          $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo n/a)"
          echo "  platform profile:  $(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo n/a)"
        '';
        usage = "Battery charge and rate from upower, whether AC is plugged in, the CPU scaling governor and the ACPI platform profile.";
      }
      {
        command = [
          "settings"
          "power"
          "ac"
        ];
        title = "Force TLP into AC mode";
        script = mode "ac" "ac";
        usage = "Runs `tlp ac`, applying the AC settings until the next power source change or `t3os settings power auto`. Requires sudo.";
      }
      {
        command = [
          "settings"
          "power"
          "battery"
        ];
        title = "Force TLP into battery mode";
        script = mode "battery" "bat";
        usage = "Runs `tlp bat`, applying the battery settings until the next power source change or `t3os settings power auto`. Requires sudo.";
      }
      {
        command = [
          "settings"
          "power"
          "auto"
        ];
        title = "Let TLP pick the mode from the power source again";
        script = mode "auto" "start";
        usage = "Runs `tlp start`, which drops a forced mode and follows the power source again. Requires sudo.";
      }
    ];
  };
}
