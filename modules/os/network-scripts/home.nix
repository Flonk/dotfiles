{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.skynet.module.os."network-scripts";

  wifiLimit = pkgs.writeShellScriptBin "skynet-wifi-limit" ''
    set -euo pipefail

    IFB_DEV="ifb4wifi0"
    IP_BIN="${pkgs.iproute2}/bin/ip"
    TC_BIN="${pkgs.iproute2}/bin/tc"
    MODPROBE_BIN="${pkgs.kmod}/bin/modprobe"
    NMCLI_BIN="${pkgs.networkmanager}/bin/nmcli"
    GREP_BIN="${pkgs.gnugrep}/bin/grep"
    AWK_BIN="${pkgs.gawk}/bin/awk"
    SUDO_BIN="/run/wrappers/bin/sudo"
    BASENAME_BIN="${pkgs.coreutils}/bin/basename"
    HEAD_BIN="${pkgs.coreutils}/bin/head"

    require_root() {
      if [[ $EUID -ne 0 ]]; then
        exec "$SUDO_BIN" "$0" "$@"
      fi
    }

    all_wifi_ifaces() {
      local found=0
      local path=""

      for path in /sys/class/net/*/wireless; do
        [[ -e "$path" ]] || continue
        found=1
        "$BASENAME_BIN" "$(dirname "$path")"
      done

      if [[ $found -eq 0 ]]; then
        "$NMCLI_BIN" -t -f DEVICE,TYPE device status | "$AWK_BIN" -F: '
          $1 != "" && $2 == "wifi" {
            print $1
            exit
          }
        '
      fi
    }

    detect_wifi_iface() {
      local iface=""

      iface="$("$NMCLI_BIN" -t -f DEVICE,TYPE,STATE device status | "$AWK_BIN" -F: '
        $1 != "" && $2 == "wifi" && $3 == "connected" {
          print $1
          exit
        }
        $1 != "" && $2 == "wifi" && fallback == "" {
          fallback = $1
        }
        END {
          if (fallback != "") {
            print fallback
          }
        }
      ')"

      if [[ -n "$iface" ]]; then
        echo "$iface"
        return 0
      fi

      iface="$(all_wifi_ifaces | "$HEAD_BIN" -n1)"
      if [[ -n "$iface" ]]; then
        echo "$iface"
        return 0
      fi

      echo "No Wi-Fi interface found." >&2
      exit 1
    }

    ensure_ifb() {
      "$MODPROBE_BIN" ifb numifbs=1

      if ! "$IP_BIN" link show dev "$IFB_DEV" >/dev/null 2>&1; then
        "$IP_BIN" link add "$IFB_DEV" type ifb
      fi

      "$IP_BIN" link set dev "$IFB_DEV" up
    }

    set_limit() {
      local iface="$1"
      local rate="$2"

      ensure_ifb

      "$TC_BIN" qdisc replace dev "$iface" ingress
      "$TC_BIN" filter add dev "$iface" parent ffff: protocol all u32 match u32 0 0 action mirred egress redirect dev "$IFB_DEV"
      "$TC_BIN" qdisc replace dev "$IFB_DEV" root netem rate "$rate"

      echo "Wi-Fi download on $iface is now limited to $rate."
    }

    clear_limit() {
      local iface=""

      while IFS= read -r iface; do
        [[ -n "$iface" ]] || continue

        if "$TC_BIN" qdisc show dev "$iface" | "$GREP_BIN" -Fq "ingress"; then
          "$TC_BIN" qdisc del dev "$iface" ingress
        fi
      done < <(all_wifi_ifaces)

      if "$IP_BIN" link show dev "$IFB_DEV" >/dev/null 2>&1; then
        if "$TC_BIN" qdisc show dev "$IFB_DEV" | "$GREP_BIN" -Fq "netem"; then
          "$TC_BIN" qdisc del dev "$IFB_DEV" root
        fi

        "$IP_BIN" link delete "$IFB_DEV"
      fi

      echo "Wi-Fi download throttling disabled."
    }

    show_status() {
      local iface=""
      local ifb_qdisc=""

      iface="$(detect_wifi_iface)"
      echo "Wi-Fi interface: $iface"

      if ! "$IP_BIN" link show dev "$IFB_DEV" >/dev/null 2>&1; then
        echo "Download shaping: disabled"
        return 0
      fi

      if ! "$TC_BIN" qdisc show dev "$iface" | "$GREP_BIN" -Fq "ingress"; then
        echo "Download shaping: disabled"
        return 0
      fi

      ifb_qdisc="$("$TC_BIN" qdisc show dev "$IFB_DEV")"
      if ! printf '%s\n' "$ifb_qdisc" | "$GREP_BIN" -Fq "netem"; then
        echo "Download shaping: disabled"
        return 0
      fi

      echo "Download shaping: enabled"
      printf '%s\n' "$ifb_qdisc"
    }

    main() {
      local command="''${1:-}"
      local rate="''${2:-}"

      case "$command" in
        set)
          if [[ -z "$rate" || $# -ne 2 ]]; then
            echo "Usage: skynet-wifi-limit set <rate>" >&2
            exit 1
          fi

          rate="''${rate,,}"
          if [[ ! "$rate" =~ ^[0-9]+([.][0-9]+)?([kmg]bit)$ ]]; then
            echo "Invalid rate '$rate'. Use values like 512kbit, 8mbit, or 1gbit." >&2
            exit 1
          fi

          require_root "$@"
          set_limit "$(detect_wifi_iface)" "$rate"
          ;;
        clear)
          require_root "$@"
          clear_limit
          ;;
        status)
          show_status
          ;;
        *)
          echo "Usage: skynet-wifi-limit <set <rate>|clear|status>" >&2
          exit 1
          ;;
      esac
    }

    main "$@"
  '';

  mkWifiScript =
    name: command:
    pkgs.writeShellScript "${name}.sh" ''
      set -euo pipefail
      exec ${wifiLimit}/bin/skynet-wifi-limit ${command}
    '';

  mkWifiForwardingScript =
    name: command:
    pkgs.writeShellScript "${name}.sh" ''
      set -euo pipefail
      exec ${wifiLimit}/bin/skynet-wifi-limit ${command} "$@"
    '';
in
{
  config = lib.mkIf cfg.enable {
    skynet.cli.scripts = [
      {
        command = [
          "wifi"
          "ultraslow"
        ];
        title = "Throttle Wi-Fi to ultraslow (128 kbit/s)";
        script = mkWifiScript "wifi-ultraslow" "set 128kbit";
        usage = "Limit Wi-Fi download speed to 128 kbit/s via tc and an ifb device. Requires sudo.";
      }
      {
        command = [
          "wifi"
          "3g"
        ];
        title = "Throttle Wi-Fi to 3G (1500 kbit/s)";
        script = mkWifiScript "wifi-3g" "set 1500kbit";
        usage = "Limit Wi-Fi download speed to roughly 3G speeds (1500 kbit/s). Requires sudo.";
      }
      {
        command = [
          "wifi"
          "4g"
        ];
        title = "Throttle Wi-Fi to 4G (12 mbit/s)";
        script = mkWifiScript "wifi-4g" "set 12mbit";
        usage = "Limit Wi-Fi download speed to a typical 4G-ish rate (12 mbit/s). Requires sudo.";
      }
      {
        command = [
          "wifi"
          "5g"
        ];
        title = "Throttle Wi-Fi to 5G (80 mbit/s)";
        script = mkWifiScript "wifi-5g" "set 80mbit";
        usage = "Limit Wi-Fi download speed to a typical 5G-ish rate (80 mbit/s). Requires sudo.";
      }
      {
        command = [
          "wifi"
          "custom"
        ];
        title = "Throttle Wi-Fi to a custom rate";
        script = mkWifiForwardingScript "wifi-custom" "set";
        usage = "Limit Wi-Fi download speed to any tc rate, e.g. 'skynet wifi custom 8mbit'. Requires sudo.";
      }
      {
        command = [
          "wifi"
          "off"
        ];
        title = "Disable Wi-Fi throttling";
        script = mkWifiScript "wifi-off" "clear";
        usage = "Remove the Wi-Fi download limit and delete the temporary ifb device. Requires sudo.";
      }
      {
        command = [
          "wifi"
          "status"
        ];
        title = "Show Wi-Fi throttling status";
        script = mkWifiScript "wifi-status" "status";
        usage = "Show the active Wi-Fi interface and current tc/netem shaping state.";
      }
    ];
  };
}
