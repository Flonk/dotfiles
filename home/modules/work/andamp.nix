# vpn-obk-split.nix (Home-Manager)
{
  pkgs,
  config,
  inputs,
  ...
}:
let
  vpnLauncher =
    inputs.openconnect-pulse-launcher.packages."${pkgs.system}".openconnect-pulse-launcher;
  vpnLite = pkgs.writeShellScriptBin "vpn-obk" ''
    set -euo pipefail
    PRE_DEV="$(${pkgs.iproute2}/bin/ip route show default | ${pkgs.gawk}/bin/awk '/^default/ {print $5; exit}')"
    PRE_GW="$(${pkgs.iproute2}/bin/ip route show default | ${pkgs.gawk}/bin/awk '/^default/ {print $3; exit}')"

    VPN_HOST_FILE="${config.sops.secrets.vpn3ithost.path}"
    "${vpnLauncher}/bin/openconnect-pulse-launcher" "$(${pkgs.bat}/bin/bat -pp "''${VPN_HOST_FILE}")" &
    VPN_PID=$!

    # wait for a *new* default route dev (the VPN dev)
    for i in $(seq 1 60); do
      NEW_DEV="$(${pkgs.iproute2}/bin/ip route show default | ${pkgs.gawk}/bin/awk -v W="''${PRE_DEV}" '/^default/ && $5 != W {print $5; exit}')"
      [ -n "''${NEW_DEV}" ] && break
      sleep 0.5
    done

    if [ -n "''${NEW_DEV}" ]; then
      sudo ${pkgs.iproute2}/bin/ip route del default dev "''${NEW_DEV}" || true
      sudo ${pkgs.iproute2}/bin/ip route replace default via "''${PRE_GW}" dev "''${PRE_DEV}" metric 100
    fi

    echo "VPN up; internet via ''${PRE_DEV}. Ctrl+C to stop."
    wait "''${VPN_PID}"
  '';
in
{
  home.packages = [
    vpnLauncher
    vpnLite
  ];

  # your secrets (unchanged)
  sops.secrets.andamp-vpn = {
    format = "binary";
    sopsFile = ../../../assets/secrets/andamp-vpn.ovpn;
  };
  sops.secrets.vpn3ithost = {
    key = "vpn3ithost";
    sopsFile = ../../../assets/secrets/secrets.json;
  };

  # keep your idempotent import service as before (if you still need it)
  systemd.user.services.import-andamp-vpn = {
    Unit = {
      Description = "Import andamp-vpn profile to NetworkManager (idempotent)";
      After = [ "default.target" ];
      ConditionPathExists = "${config.sops.secrets.andamp-vpn.path}";
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = (
        pkgs.writeShellScript "import-andamp-vpn" ''
          set -euo pipefail
          NAME="andamp-vpn"
          if ${pkgs.networkmanager}/bin/nmcli -t -f NAME con show | ${pkgs.gnugrep}/bin/grep -Fq "$NAME"; then
            echo "$NAME already present; skipping import."
            exit 0
          fi
          echo "Importing $NAME from ${config.sops.secrets.andamp-vpn.path}"
          ${pkgs.networkmanager}/bin/nmcli connection import type openvpn file "${config.sops.secrets.andamp-vpn.path}"
        ''
      );
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
