{
  pkgs,
  ...
}:
let
  qsEnvPath = "/run/user/%U/quickshell.env";

  qsPowerToggle = pkgs.writeShellScript "quickshell-power-toggle" ''
    set -euo pipefail
    shopt -s nullglob

    write_qs_env() {
      local hp pid envfile
      envfile="''${QS_ENV_FILE}"

      hp="$(pidof hyprland || true)"
      if [ -z "''${hp}" ]; then
        hp="$(pidof Hyprland || true)"
      fi
      if [ -n "''${hp}" ]; then
        pid="''${hp%% *}"
        tr '\0' '\n' < "/proc/''${pid}/environ" | grep -E '^(WAYLAND_DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS|HYPRLAND_INSTANCE_SIGNATURE|DISPLAY)='
          > "''${envfile}.tmp" || true
        if [ -s "''${envfile}.tmp" ]; then
          mv "''${envfile}.tmp" "''${envfile}"
          chmod 0600 "''${envfile}"
          echo "[qs-toggle] wrote env from Hyprland pid=''${pid} → ''${envfile}"
          return 0
        fi
      fi
      echo "[qs-toggle] could not capture Hyprland env; keeping existing env file if any"
      return 1
    }

    ac_sysfs() {
      for d in /sys/class/power_supply/*; do
        [ -f "''${d}/type" ] || continue
        t="$(cat "''${d}/type")"
        case "''${t}" in
          Mains|AC|USB|USB_C|USB-PD|USB_PD|USB-C)
            if [ -f "''${d}/online" ] && [ "$(cat "''${d}/online")" = "1" ]; then
              return 0
            fi
          ;;
        esac
      done
      return 1
    }

    ac_upower() {
      if command -v upower >/dev/null 2>&1; then
        dev="$(upower -e 2>/dev/null | grep -m1 DisplayDevice || true)"
        if [ -n "''${dev}" ]; then
          state="$(upower -i "''${dev}" 2>/dev/null | awk -F: '/^\s*state/ {gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2; exit}')"
          case "''${state}" in
            charging|fully-charged|pending-charge) return 0 ;;
          esac
        fi
      fi
      return 1
    }

    is_on_ac() { ac_sysfs || ac_upower; }

    : "''${QS_ENV_FILE:?QS_ENV_FILE not set}"

    last=unknown

    start_qs() {
      write_qs_env || true
      systemctl --user start quickshell.service || true
    }

    stop_qs() {
      systemctl --user stop quickshell.service || true
    }

    start_waybar() {
      write_qs_env || true
      systemctl --user start waybar.service || true
    }

    stop_waybar() {
      systemctl --user stop waybar.service || true
    }

    apply_once() {
      if is_on_ac; then
        if [ "''${last}" != "ac" ]; then
          echo "[qs-toggle] AC → QuickShell"
          stop_waybar
          start_qs
          last=ac
        fi
      else
        if [ "''${last}" != "bat" ]; then
          echo "[qs-toggle] Battery → Waybar"
          stop_qs
          start_waybar
          last=bat
        fi
      fi
    }

    apply_once
    while sleep 2; do
      apply_once
    done
  '';

in
{
  systemd.user.services.quickshell-power-toggle = {
    Unit = {
      Description = "Toggle QuickShell on AC/battery (sysfs+UPower, with env capture)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      Environment = [ "QS_ENV_FILE=${qsEnvPath}" ];
      ExecStart = qsPowerToggle;
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
