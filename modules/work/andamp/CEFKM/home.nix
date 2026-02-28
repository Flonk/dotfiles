{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  vpnLauncher =
    inputs.openconnect-pulse-launcher.packages."${pkgs.stdenv.hostPlatform.system
    }".openconnect-pulse-launcher;

  # vpn lite via ssh tunnels; doesn't work for everything (especially kube port forwards
  # collide with this), but for simple tasks this is enough
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
      # The VPN device appears before the VPN client finishes configuring routes.
      # Enforcing routing immediately causes a race: openconnect's setup script
      # may add/re-add the default route *after* we've already removed it.
      # Wait for the client to settle, then enforce twice to catch late additions.
      echo "VPN device ''${NEW_DEV} up, waiting for client to finish route setup..."
      sleep 4
      sudo ${pkgs.iproute2}/bin/ip route del default dev "''${NEW_DEV}" 2>/dev/null || true
      sudo ${pkgs.iproute2}/bin/ip route replace default via "''${PRE_GW}" dev "''${PRE_DEV}" metric 100
      # Second pass: catch anything the client added during or after the first pass
      sleep 3
      sudo ${pkgs.iproute2}/bin/ip route del default dev "''${NEW_DEV}" 2>/dev/null || true
      sudo ${pkgs.iproute2}/bin/ip route replace default via "''${PRE_GW}" dev "''${PRE_DEV}" metric 100 2>/dev/null || true
    fi

    echo "VPN up; internet via ''${PRE_DEV}. Ctrl+C to stop."
    wait "''${VPN_PID}"
  '';
in
{
  imports = [
    ./insomnia.nix
  ];

  config = lib.mkIf config.skynet.module.andamp.CEFKM {
    home.packages = [
      vpnLauncher
    ];

    skynet.cli.scripts = [
      {
        command = [
          "cefkm"
          "vpn"
        ];
        title = "Connect to CEFKM VPN";
        script = "${vpnLite}/bin/vpn-obk";
        usage = "Connect to CEFKM VPN via openconnect-pulse-launcher.";
      }
    ];

    sops.secrets.vpn3ithost = {
      key = "vpn3ithost";
      sopsFile = ./secrets/secrets.json;
    };
  };
}
